// Configuration
const CORRECT_PASSWORD = '1312';
const PASSWORD_CHECK_DELAY = 2000; // 2 seconds

// API Keys - ADD YOUR KEYS HERE
const API_KEYS = {
    gemini: 'AIzaSyBh_v2GjsXZdyMoU7kQNaCadJZS4taEA1E',  // Get from: https://makersuite.google.com/app/apikey
    openrouter: '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',  // Get from: https://openrouter.ai/keys
    ollama: ''  // Not needed - leave empty
};

// API Endpoints
const API_ENDPOINTS = {
    gemini: 'https://generativelanguage.googleapis.com/v1beta/models',
    openrouter: 'https://openrouter.ai/api/v1/chat/completions',
    ollama: 'https://ollama.nov.api.zukijourney.com/v1/chat/completions'  // Alternative working endpoint
};

// AI Settings (defaults)
let aiSettings = {
    provider: 'ollama', // gemini, openrouter, ollama
    model: 'llama-3.1-70b', // Default model per provider
    systemPrompt: 'You are a helpful AI assistant.',
    temperature: 0.7,
    maxTokens: 2000,
    topP: 0.9,
    thinkingLevel: 'low' // Gemini thinking level: minimal, low, medium, high
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
        switch (aiSettings.provider) {
            case 'gemini':
                return await sendToGemini(message);
            case 'openrouter':
                return await sendToOpenRouter(message);
            case 'ollama':
                return await sendToOllama(message);
            default:
                throw new Error(`Unknown provider: ${aiSettings.provider}`);
        }
    } catch (error) {
        console.error('AI Error:', error);
        throw error;
    }
}

async function sendToGemini(message) {
    try {
        // Build conversation history in new Interactions API format
        const input = [];
        
        // Add conversation history
        conversationHistory.forEach(msg => {
            if (msg.role === 'user') {
                input.push({
                    role: 'user',
                    content: [{ type: 'text', text: msg.content }]
                });
            } else if (msg.role === 'assistant') {
                input.push({
                    role: 'model',
                    content: [{ type: 'text', text: msg.content }]
                });
            }
        });
        
        const requestBody = {
            model: aiSettings.model,
            input: input,
            generation_config: {
                temperature: aiSettings.temperature,
                max_output_tokens: aiSettings.maxTokens,
                top_p: aiSettings.topP,
                thinking_level: aiSettings.thinkingLevel
            }
        };
        
        // Add system instruction if present
        if (aiSettings.systemPrompt && aiSettings.systemPrompt.trim()) {
            requestBody.system_instruction = aiSettings.systemPrompt;
        }
        
        const url = `https://generativelanguage.googleapis.com/v1beta/interactions:create?key=${API_KEYS.gemini}`;
        
        const response = await fetch(url, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(requestBody)
        });
        
        if (!response.ok) {
            const errorText = await response.text();
            throw new Error(`Gemini API failed: ${response.status} - ${errorText}`);
        }
        
        const data = await response.json();
        
        // Extract text from outputs array
        if (!data.outputs || data.outputs.length === 0) {
            throw new Error('Invalid Gemini response format: no outputs');
        }
        
        // Find the last text output (skip thoughts)
        let textOutput = null;
        for (let i = data.outputs.length - 1; i >= 0; i--) {
            if (data.outputs[i].type === 'text') {
                textOutput = data.outputs[i].text;
                break;
            }
        }
        
        if (!textOutput) {
            throw new Error('No text output found in response');
        }
        
        return textOutput;
    } catch (error) {
        console.error('Gemini Error:', error);
        throw error;
    }
}

async function sendToOpenRouter(message) {
    try {
        const messages = [];
        
        if (aiSettings.systemPrompt && aiSettings.systemPrompt.trim()) {
            messages.push({
                role: 'system',
                content: aiSettings.systemPrompt
            });
        }
        
        messages.push(...conversationHistory);
        
        const requestBody = {
            model: aiSettings.model,
            messages: messages,
            temperature: aiSettings.temperature,
            max_tokens: aiSettings.maxTokens,
            top_p: aiSettings.topP
        };
        
        const response = await fetch(API_ENDPOINTS.openrouter, {
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${API_KEYS.openrouter}`,
                'Content-Type': 'application/json',
                'HTTP-Referer': window.location.href,
                'X-Title': 'Venice AI Chat'
            },
            body: JSON.stringify(requestBody)
        });
        
        if (!response.ok) {
            const errorText = await response.text();
            throw new Error(`OpenRouter API failed: ${response.status} - ${errorText}`);
        }
        
        const data = await response.json();
        
        if (!data.choices || !data.choices[0] || !data.choices[0].message) {
            throw new Error('Invalid OpenRouter response format');
        }
        
        return data.choices[0].message.content;
    } catch (error) {
        console.error('OpenRouter Error:', error);
        throw error;
    }
}

async function sendToOllama(message) {
    try {
        const messages = [];
        
        if (aiSettings.systemPrompt && aiSettings.systemPrompt.trim()) {
            messages.push({
                role: 'system',
                content: aiSettings.systemPrompt
            });
        }
        
        messages.push(...conversationHistory);
        
        const requestBody = {
            model: aiSettings.model,
            messages: messages,
            temperature: aiSettings.temperature,
            max_tokens: aiSettings.maxTokens,
            top_p: aiSettings.topP,
            stream: false
        };
        
        const response = await fetch(API_ENDPOINTS.ollama, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer anything'  // Some endpoints need a token placeholder
            },
            body: JSON.stringify(requestBody)
        });
        
        if (!response.ok) {
            const errorText = await response.text();
            throw new Error(`Ollama API failed: ${response.status} - ${errorText}`);
        }
        
        const data = await response.json();
        
        // Handle OpenAI-compatible response format
        if (data.choices && data.choices[0] && data.choices[0].message) {
            return data.choices[0].message.content;
        }
        
        // Handle Ollama native format
        if (data.message && data.message.content) {
            return data.message.content;
        }
        
        throw new Error('Invalid Ollama response format');
    } catch (error) {
        console.error('Ollama Error:', error);
        throw error;
    }
}

// Model options per provider
const MODEL_OPTIONS = {
    gemini: [
        { value: 'gemini-3-flash-preview', label: 'Gemini 3 Flash (Preview)' },
        { value: 'gemini-2.5-flash', label: 'Gemini 2.5 Flash' },
        { value: 'gemini-2.5-pro', label: 'Gemini 2.5 Pro' },
        { value: 'gemini-3-pro-preview', label: 'Gemini 3 Pro (Preview)' }
    ],
    openrouter: [
        { value: 'meta-llama/llama-3.3-70b-instruct', label: 'Llama 3.3 70B' },
        { value: 'anthropic/claude-3.5-sonnet', label: 'Claude 3.5 Sonnet' },
        { value: 'google/gemini-pro-1.5', label: 'Gemini Pro 1.5' },
        { value: 'mistralai/mistral-large', label: 'Mistral Large' }
    ],
    ollama: [
        { value: 'llama-3.1-70b', label: 'Llama 3.1 70B' },
        { value: 'llama-3.1-8b', label: 'Llama 3.1 8B' },
        { value: 'gemma-2-9b', label: 'Gemma 2 9B' },
        { value: 'mistral-7b', label: 'Mistral 7B' },
        { value: 'qwen-2-7b', label: 'Qwen 2 7B' }
    ]
};

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
    
    // Provider change handler
    document.getElementById('providerSelect').addEventListener('change', (e) => {
        const provider = e.target.value;
        updateModelOptions(provider);
        updateProviderSpecificSettings(provider);
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

function updateModelOptions(provider) {
    const modelSelect = document.getElementById('modelSelect');
    modelSelect.innerHTML = '';
    
    const options = MODEL_OPTIONS[provider] || [];
    options.forEach(opt => {
        const option = document.createElement('option');
        option.value = opt.value;
        option.textContent = opt.label;
        modelSelect.appendChild(option);
    });
    
    // Set first option as default if current model not in list
    if (options.length > 0 && !options.find(o => o.value === aiSettings.model)) {
        modelSelect.value = options[0].value;
    }
}

function updateProviderSpecificSettings(provider) {
    const thinkingLevelGroup = document.getElementById('thinkingLevelGroup');
    
    // Show thinking level only for Gemini
    if (provider === 'gemini') {
        thinkingLevelGroup.style.display = 'block';
    } else {
        thinkingLevelGroup.style.display = 'none';
    }
}

function updateSettingsUI() {
    document.getElementById('providerSelect').value = aiSettings.provider;
    document.getElementById('systemPrompt').value = aiSettings.systemPrompt;
    document.getElementById('temperature').value = aiSettings.temperature;
    document.getElementById('tempValue').textContent = aiSettings.temperature;
    document.getElementById('maxTokens').value = aiSettings.maxTokens;
    document.getElementById('tokensValue').textContent = aiSettings.maxTokens;
    document.getElementById('topP').value = aiSettings.topP;
    document.getElementById('topPValue').textContent = aiSettings.topP;
    
    // Update model options and provider-specific settings
    updateModelOptions(aiSettings.provider);
    updateProviderSpecificSettings(aiSettings.provider);
    
    // Set current model
    document.getElementById('modelSelect').value = aiSettings.model;
    
    // Set thinking level if Gemini
    if (aiSettings.thinkingLevel) {
        document.getElementById('thinkingLevel').value = aiSettings.thinkingLevel;
    }
}

function saveSettingsFromUI() {
    aiSettings.provider = document.getElementById('providerSelect').value;
    aiSettings.model = document.getElementById('modelSelect').value;
    aiSettings.systemPrompt = document.getElementById('systemPrompt').value;
    aiSettings.temperature = parseFloat(document.getElementById('temperature').value);
    aiSettings.maxTokens = parseInt(document.getElementById('maxTokens').value);
    aiSettings.topP = parseFloat(document.getElementById('topP').value);
    
    // Save thinking level if Gemini
    if (aiSettings.provider === 'gemini') {
        aiSettings.thinkingLevel = document.getElementById('thinkingLevel').value;
    }
    
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
