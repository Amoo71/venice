// Configuration
const CORRECT_PASSWORD = '1312';
const VENICE_API_KEY = 'VENICE-ADMIN-KEY-FUtsSazB_UZc15v2gPH07kOb8UY7nzRzh2wlAy8trF'; // Replace with actual API key
const VENICE_API_URL = 'https://api.venice.ai/api/v1/chat/completions';
const PASSWORD_CHECK_DELAY = 2000; // 2 seconds

// AI Settings (defaults)
let aiSettings = {
    model: 'venice-uncensored',
    systemPrompt: '',
    temperature: 0.7,
    maxTokens: 2000,
    topP: 0.9,
    frequencyPenalty: 0,
    presencePenalty: 0,
    webSearch: 'off',
    includeVeniceSystemPrompt: true
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
        
        const response = await sendToVeniceAI(message);
        
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
        await addMessageWithTypewriter('assistant', 'Sorry, I encountered an error. Please try again.');
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

async function sendToVeniceAI(message) {
    try {
        // Build messages array with system prompt if set
        const messages = [];
        if (aiSettings.systemPrompt && aiSettings.systemPrompt.trim()) {
            messages.push({
                role: 'system',
                content: aiSettings.systemPrompt
            });
        }
        messages.push(...conversationHistory);
        
        console.log('Sending to Venice AI:', {
            url: VENICE_API_URL,
            model: aiSettings.model,
            messages: messages
        });
        
        // Build request body
        const requestBody = {
            model: aiSettings.model,
            messages: messages,
            temperature: aiSettings.temperature,
            max_tokens: aiSettings.maxTokens,
            top_p: aiSettings.topP,
            frequency_penalty: aiSettings.frequencyPenalty,
            presence_penalty: aiSettings.presencePenalty
        };
        
        // Add Venice-specific parameters
        const veniceParams = {
            include_venice_system_prompt: aiSettings.includeVeniceSystemPrompt
        };
        
        if (aiSettings.webSearch !== 'off') {
            veniceParams.enable_web_search = aiSettings.webSearch;
        }
        
        requestBody.venice_parameters = veniceParams;
        
        const response = await fetch(VENICE_API_URL, {
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${VENICE_API_KEY}`,
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(requestBody)
        });
        
        console.log('Response status:', response.status);
        
        if (!response.ok) {
            const errorText = await response.text();
            console.error('API Error Response:', errorText);
            throw new Error(`API request failed: ${response.status} - ${errorText}`);
        }
        
        const data = await response.json();
        console.log('API Response:', data);
        
        if (!data.choices || !data.choices[0] || !data.choices[0].message) {
            throw new Error('Invalid API response format');
        }
        
        return data.choices[0].message.content;
    } catch (error) {
        console.error('Venice AI Error Details:', error);
        throw error;
    }
}

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
    
    document.getElementById('frequencyPenalty').addEventListener('input', (e) => {
        document.getElementById('freqValue').textContent = e.target.value;
    });
    
    document.getElementById('presencePenalty').addEventListener('input', (e) => {
        document.getElementById('presValue').textContent = e.target.value;
    });
}

function updateSettingsUI() {
    document.getElementById('modelSelect').value = aiSettings.model;
    document.getElementById('systemPrompt').value = aiSettings.systemPrompt;
    document.getElementById('temperature').value = aiSettings.temperature;
    document.getElementById('tempValue').textContent = aiSettings.temperature;
    document.getElementById('maxTokens').value = aiSettings.maxTokens;
    document.getElementById('tokensValue').textContent = aiSettings.maxTokens;
    document.getElementById('topP').value = aiSettings.topP;
    document.getElementById('topPValue').textContent = aiSettings.topP;
    document.getElementById('frequencyPenalty').value = aiSettings.frequencyPenalty;
    document.getElementById('freqValue').textContent = aiSettings.frequencyPenalty;
    document.getElementById('presencePenalty').value = aiSettings.presencePenalty;
    document.getElementById('presValue').textContent = aiSettings.presencePenalty;
    document.getElementById('webSearch').value = aiSettings.webSearch;
    document.getElementById('veniceSystemPrompt').checked = aiSettings.includeVeniceSystemPrompt;
}

function saveSettingsFromUI() {
    aiSettings.model = document.getElementById('modelSelect').value;
    aiSettings.systemPrompt = document.getElementById('systemPrompt').value;
    aiSettings.temperature = parseFloat(document.getElementById('temperature').value);
    aiSettings.maxTokens = parseInt(document.getElementById('maxTokens').value);
    aiSettings.topP = parseFloat(document.getElementById('topP').value);
    aiSettings.frequencyPenalty = parseFloat(document.getElementById('frequencyPenalty').value);
    aiSettings.presencePenalty = parseFloat(document.getElementById('presencePenalty').value);
    aiSettings.webSearch = document.getElementById('webSearch').value;
    aiSettings.includeVeniceSystemPrompt = document.getElementById('veniceSystemPrompt').checked;
    
    // Save to localStorage
    localStorage.setItem('veniceAISettings', JSON.stringify(aiSettings));
    console.log('Settings saved:', aiSettings);
}

function loadSettings() {
    const saved = localStorage.getItem('veniceAISettings');
    if (saved) {
        try {
            aiSettings = JSON.parse(saved);
            console.log('Settings loaded:', aiSettings);
        } catch (e) {
            console.error('Failed to load settings:', e);
        }
    }
}
