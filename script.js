// Configuration
const CORRECT_PASSWORD = '1312';
const PASSWORD_CHECK_DELAY = 2000; // 2 seconds

// HuggingFace Inference API Configuration
const HF_API_ENDPOINT = 'https://api-inference.huggingface.co/models/';
const DEFAULT_HF_MODEL = 'mistralai/Mistral-7B-Instruct-v0.2';
const HF_API_KEY = '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'; // Free tier API key

// AI Settings (defaults)
let aiSettings = {
    model: DEFAULT_HF_MODEL,
    systemPrompt: 'You are a helpful AI assistant.',
    temperature: 0.7,
    maxTokens: 2000,
    topP: 0.9
};

// State
let passwordTimeout = null;
let conversationHistory = [];
let isProcessing = false;

// DOM Elements
const passwordGate = document.getElementById('passwordGate');
const mainInterface = document.getElementById('mainInterface');
const passwordInput = document.getElementById('passwordInput');
const messageInput = document.getElementById('messageInput');
const sendButton = document.getElementById('sendButton');
const messagesContainer = document.getElementById('messagesContainer');
const typingPreview = document.getElementById('typingPreview');
const typingPreviewText = document.getElementById('typingPreviewText');

// Settings elements
const settingsButton = document.getElementById('settingsButton');
const settingsModal = document.getElementById('settingsModal');
const closeSettings = document.getElementById('closeSettings');
const saveSettings = document.getElementById('saveSettings');
const clearChatButton = document.getElementById('clearChatButton');

// Initialize
document.addEventListener('DOMContentLoaded', () => {
    initializePasswordGate();
    initializeChatInterface();
    initializeSettings();
    loadSettings();
});

// Password Gate Logic
function initializePasswordGate() {
    passwordInput.addEventListener('input', handlePasswordInput);
    passwordInput.focus();
}

function handlePasswordInput(e) {
    const value = e.target.value;
    
    // Clear existing timeout
    if (passwordTimeout) {
        clearTimeout(passwordTimeout);
    }
    
    // Only check if we have 4 characters
    if (value.length === 4) {
        passwordTimeout = setTimeout(() => {
            checkPassword(value);
        }, PASSWORD_CHECK_DELAY);
    }
}

function checkPassword(password) {
    if (password === CORRECT_PASSWORD) {
        unlockInterface();
    } else {
        showPasswordError();
    }
}

function showPasswordError() {
    passwordInput.classList.add('error');
    passwordInput.value = '';
    
    setTimeout(() => {
        passwordInput.classList.remove('error');
    }, 400);
}

function unlockInterface() {
    passwordGate.style.animation = 'fadeOut 0.6s ease-out forwards';
    
    setTimeout(() => {
        passwordGate.style.display = 'none';
        mainInterface.classList.remove('hidden');
        messageInput.focus();
    }, 600);
}

// Add fadeOut animation
const style = document.createElement('style');
style.textContent = `
    @keyframes fadeOut {
        from {
            opacity: 1;
        }
        to {
            opacity: 0;
        }
    }
`;
document.head.appendChild(style);

// Chat Interface Logic
function initializeChatInterface() {
    sendButton.addEventListener('click', handleSendMessage);
    messageInput.addEventListener('keydown', handleMessageKeydown);
    messageInput.addEventListener('input', handleMessageInput);
    clearChatButton.addEventListener('click', clearChat);
}

function clearChat() {
    // Clear conversation history
    conversationHistory = [];
    
    // Clear all messages
    const messages = messagesContainer.querySelectorAll('.message');
    messages.forEach(msg => msg.remove());
    
    // Show welcome message
    const welcomeDiv = document.createElement('div');
    welcomeDiv.className = 'welcome-message';
    messagesContainer.innerHTML = '';
    
    console.log('Chat cleared - new session started');
}

function handleMessageInput() {
    autoResizeTextarea();
    updateTypingPreview();
}

function updateTypingPreview() {
    const text = messageInput.value.trim();
    
    if (text.length > 0 && !isProcessing) {
        typingPreviewText.textContent = text;
        typingPreview.classList.remove('hidden');
    } else {
        typingPreview.classList.add('hidden');
    }
}

function handleMessageKeydown(e) {
    if (e.key === 'Enter' && !e.shiftKey) {
        e.preventDefault();
        handleSendMessage();
    }
}

function autoResizeTextarea() {
    messageInput.style.height = 'auto';
    messageInput.style.height = messageInput.scrollHeight + 'px';
}

async function handleSendMessage() {
    const message = messageInput.value.trim();
    
    if (!message || isProcessing) return;
    
    // Clear input and hide typing preview
    messageInput.value = '';
    messageInput.style.height = 'auto';
    typingPreview.classList.add('hidden');
    
    // Remove welcome message if present
    const welcomeMsg = messagesContainer.querySelector('.welcome-message');
    if (welcomeMsg) {
        welcomeMsg.remove();
    }
    
    // Add user message
    addMessage('user', message);
    
    // Add to conversation history
    conversationHistory.push({
        role: 'user',
        content: message
    });
    
    // Show loading indicator
    const loadingId = addLoadingMessage();
    
    // Send to Venice AI
    try {
        isProcessing = true;
        sendButton.disabled = true;
        
        const response = await sendToAI(message);
        
        // Remove loading indicator
        removeLoadingMessage(loadingId);
        
        // Add assistant response with typewriter effect
        await addMessageWithTypewriter('assistant', response);
        
        // Add to conversation history
        conversationHistory.push({
            role: 'assistant',
            content: response
        });
        
    } catch (error) {
        console.error('Error:', error);
        removeLoadingMessage(loadingId);
        
        // Show actual error message instead of generic one
        let errorMessage = 'Error: ';
        if (error.message) {
            errorMessage += error.message;
        } else {
            errorMessage += 'Unknown error occurred. Check console for details.';
        }
        
        await addMessageWithTypewriter('assistant', errorMessage);
    } finally {
        isProcessing = false;
        sendButton.disabled = false;
        messageInput.focus();
    }
}

function addMessage(role, content) {
    const messageDiv = document.createElement('div');
    messageDiv.className = `message ${role}`;
    
    const avatar = document.createElement('div');
    avatar.className = 'message-avatar';
    avatar.textContent = role === 'user' ? '👤' : '🤖';
    
    const contentDiv = document.createElement('div');
    contentDiv.className = 'message-content';
    contentDiv.textContent = content;
    
    messageDiv.appendChild(avatar);
    messageDiv.appendChild(contentDiv);
    
    messagesContainer.appendChild(messageDiv);
    scrollToBottom();
}

async function addMessageWithTypewriter(role, content) {
    const messageDiv = document.createElement('div');
    messageDiv.className = `message ${role}`;
    
    const avatar = document.createElement('div');
    avatar.className = 'message-avatar';
    avatar.textContent = role === 'user' ? '👤' : '🤖';
    
    const contentDiv = document.createElement('div');
    contentDiv.className = 'message-content typing';
    contentDiv.textContent = '';
    
    messageDiv.appendChild(avatar);
    messageDiv.appendChild(contentDiv);
    
    messagesContainer.appendChild(messageDiv);
    scrollToBottom();
    
    // Typewriter effect
    const typingSpeed = 30; // milliseconds per character
    let currentIndex = 0;
    
    return new Promise((resolve) => {
        const typeInterval = setInterval(() => {
            if (currentIndex < content.length) {
                contentDiv.textContent = content.substring(0, currentIndex + 1);
                currentIndex++;
                scrollToBottom();
            } else {
                clearInterval(typeInterval);
                contentDiv.classList.remove('typing');
                resolve();
            }
        }, typingSpeed);
    });
}

function addLoadingMessage() {
    const loadingId = 'loading-' + Date.now();
    const messageDiv = document.createElement('div');
    messageDiv.className = 'message assistant';
    messageDiv.id = loadingId;
    
    const avatar = document.createElement('div');
    avatar.className = 'message-avatar';
    avatar.textContent = '🤖';
    
    const contentDiv = document.createElement('div');
    contentDiv.className = 'message-content loading';
    
    for (let i = 0; i < 3; i++) {
        const dot = document.createElement('div');
        dot.className = 'loading-dot';
        contentDiv.appendChild(dot);
    }
    
    messageDiv.appendChild(avatar);
    messageDiv.appendChild(contentDiv);
    
    messagesContainer.appendChild(messageDiv);
    scrollToBottom();
    
    return loadingId;
}

function removeLoadingMessage(loadingId) {
    const loadingMsg = document.getElementById(loadingId);
    if (loadingMsg) {
        loadingMsg.remove();
    }
}

function scrollToBottom() {
    messagesContainer.scrollTop = messagesContainer.scrollHeight;
}

async function sendToAI(message) {
    try {
        return await sendToHuggingFace(message);
    } catch (error) {
        console.error('AI Error:', error);
        
        // Provide user-friendly error messages
        let userMessage = error.message;
        
        if (error.message.includes('Failed to fetch')) {
            userMessage = '❌ Network error: Cannot connect to HuggingFace API.\n\nPossible solutions:\n• Check your internet connection\n• Try again in a moment\n• The model might be starting up (can take 20-30s)';
        } else if (error.message.includes('loading')) {
            userMessage = '⏳ Model is loading on HuggingFace servers.\n\nPlease wait 20-30 seconds and try again.\nThis is normal for the first request.';
        } else if (error.message.includes('401') || error.message.includes('403')) {
            userMessage = '🔑 API Key error.\n\nThe HuggingFace API key may be invalid.\nGet a free key at: https://huggingface.co/settings/tokens';
        } else if (error.message.includes('429')) {
            userMessage = '⏰ Rate limit exceeded.\n\nPlease wait a moment before trying again.';
        } else if (error.message.includes('500') || error.message.includes('503')) {
            userMessage = '🔧 HuggingFace server error.\n\nThe service might be temporarily down.\nTry again in a few minutes.';
        }
        
        throw new Error(userMessage);
    }
}

async function sendToHuggingFace(message, retryCount = 0) {
    const MAX_RETRIES = 3;
    const RETRY_DELAY = 3000; // 3 seconds
    
    try {
        // Build prompt from conversation history
        let prompt = '';
        
        // Add system prompt if configured
        if (aiSettings.systemPrompt && aiSettings.systemPrompt.trim()) {
            prompt += `[INST] ${aiSettings.systemPrompt} [/INST]\n\n`;
        }
        
        // Add conversation history in Mistral/Llama format
        conversationHistory.forEach(msg => {
            if (msg.role === 'user') {
                prompt += `[INST] ${msg.content} [/INST]\n`;
            } else {
                prompt += `${msg.content}\n\n`;
            }
        });
        
        const endpoint = HF_API_ENDPOINT + aiSettings.model;
        
        const requestBody = {
            inputs: prompt,
            parameters: {
                temperature: aiSettings.temperature,
                max_new_tokens: aiSettings.maxTokens,
                top_p: aiSettings.topP,
                return_full_text: false
            },
            options: {
                wait_for_model: true
            }
        };
        
        console.log('Sending to HuggingFace:', endpoint);
        
        const response = await fetch(endpoint, {
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${HF_API_KEY}`,
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(requestBody)
        });
        
        if (!response.ok) {
            const errorText = await response.text();
            let errorData;
            
            try {
                errorData = JSON.parse(errorText);
            } catch (e) {
                errorData = { error: errorText };
            }
            
            // Check if model is loading
            if (errorData.error && typeof errorData.error === 'string' && 
                (errorData.error.includes('loading') || errorData.error.includes('currently loading'))) {
                
                if (retryCount < MAX_RETRIES) {
                    console.log(`Model loading, retrying in ${RETRY_DELAY/1000}s... (attempt ${retryCount + 1}/${MAX_RETRIES})`);
                    await new Promise(resolve => setTimeout(resolve, RETRY_DELAY));
                    return await sendToHuggingFace(message, retryCount + 1);
                } else {
                    throw new Error('Model is still loading. Please wait a moment and try again.');
                }
            }
            
            throw new Error(`HuggingFace API error (${response.status}): ${errorData.error || errorText}`);
        }
        
        const data = await response.json();
        console.log('HuggingFace response:', data);
        
        // Check for error in response
        if (data.error) {
            if (data.error.includes('loading') && retryCount < MAX_RETRIES) {
                console.log(`Model loading, retrying in ${RETRY_DELAY/1000}s... (attempt ${retryCount + 1}/${MAX_RETRIES})`);
                await new Promise(resolve => setTimeout(resolve, RETRY_DELAY));
                return await sendToHuggingFace(message, retryCount + 1);
            }
            throw new Error(data.error);
        }
        
        // Parse HuggingFace response format
        if (Array.isArray(data) && data[0] && data[0].generated_text) {
            return data[0].generated_text.trim();
        }
        
        // Alternative format
        if (data.generated_text) {
            return data.generated_text.trim();
        }
        
        throw new Error('Invalid HuggingFace response format');
    } catch (error) {
        console.error('HuggingFace Error:', error);
        
        // Better error messages
        if (error.message.includes('Failed to fetch')) {
            throw new Error('Network error: Unable to reach HuggingFace API. Check your internet connection.');
        }
        
        throw error;
    }
}

// Popular HuggingFace models (free tier)
const HF_MODELS = [
    'mistralai/Mistral-7B-Instruct-v0.2',
    'mistralai/Mixtral-8x7B-Instruct-v0.1',
    'meta-llama/Llama-2-7b-chat-hf',
    'meta-llama/Llama-2-13b-chat-hf',
    'google/gemma-7b-it',
    'tiiuae/falcon-7b-instruct',
    'HuggingFaceH4/zephyr-7b-beta'
];

// Settings Functions
function initializeSettings() {
    settingsButton.addEventListener('click', () => {
        settingsModal.classList.remove('hidden');
        updateSettingsUI();
    });
    
    closeSettings.addEventListener('click', () => {
        settingsModal.classList.add('hidden');
    });
    
    saveSettings.addEventListener('click', () => {
        saveSettingsFromUI();
        settingsModal.classList.add('hidden');
    });
    
    // Close modal on backdrop click
    settingsModal.addEventListener('click', (e) => {
        if (e.target === settingsModal) {
            settingsModal.classList.add('hidden');
        }
    });
    
    // Model selection handler
    document.getElementById('modelSelect').addEventListener('change', (e) => {
        aiSettings.model = e.target.value;
    });
    
    // Update slider values in real-time
    document.getElementById('temperature').addEventListener('input', (e) => {
        document.getElementById('tempValue').textContent = e.target.value;
    });
    
    document.getElementById('maxTokens').addEventListener('input', (e) => {
        document.getElementById('tokensValue').textContent = e.target.value;
    });
    
    document.getElementById('topP').addEventListener('input', (e) => {
        document.getElementById('topPValue').textContent = e.target.value;
    });
}

// No longer needed - vLLM uses fixed model

function updateSettingsUI() {
    document.getElementById('modelSelect').value = aiSettings.model;
    document.getElementById('systemPrompt').value = aiSettings.systemPrompt;
    document.getElementById('temperature').value = aiSettings.temperature;
    document.getElementById('tempValue').textContent = aiSettings.temperature;
    document.getElementById('maxTokens').value = aiSettings.maxTokens;
    document.getElementById('tokensValue').textContent = aiSettings.maxTokens;
    document.getElementById('topP').value = aiSettings.topP;
    document.getElementById('topPValue').textContent = aiSettings.topP;
}

function saveSettingsFromUI() {
    aiSettings.model = document.getElementById('modelSelect').value;
    aiSettings.systemPrompt = document.getElementById('systemPrompt').value;
    aiSettings.temperature = parseFloat(document.getElementById('temperature').value);
    aiSettings.maxTokens = parseInt(document.getElementById('maxTokens').value);
    aiSettings.topP = parseFloat(document.getElementById('topP').value);
    
    // Save to localStorage
    localStorage.setItem('aiSettings', JSON.stringify(aiSettings));
    console.log('Settings saved:', aiSettings);
}

function loadSettings() {
    const saved = localStorage.getItem('aiSettings');
    if (saved) {
        try {
            const loadedSettings = JSON.parse(saved);
            // Merge with defaults to handle missing fields
            aiSettings = { ...aiSettings, ...loadedSettings };
            console.log('Settings loaded:', aiSettings);
        } catch (e) {
            console.error('Failed to load settings:', e);
        }
    }
}
