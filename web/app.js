const app = document.getElementById('app');
const ordersList = document.getElementById('ordersList');
const societyBalanceEl = document.getElementById('societyBalance');
const ordersCountEl = document.getElementById('ordersCount');
const lowStockCountEl = document.getElementById('lowStockCount');
const refreshBtn = document.getElementById('refreshBtn');
const closeBtn = document.getElementById('closeBtn');

const state = {
    orders: [],
    stock: {},
    societyBalance: 0,
    statuses: {}
};

function escapeHtml(value) {
    return String(value ?? '')
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#39;');
}

function formatMoney(value) {
    return Number(value || 0).toLocaleString('es-AR');
}

function postNui(eventName, payload = {}) {
    const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'nui-resource';
    return fetch(`https://${resource}/${eventName}`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8'
        },
        body: JSON.stringify(payload)
    })
        .then((res) => res.json())
        .catch(() => ({ ok: false, message: 'No hubo respuesta del juego.' }));
}

function getStatusClass(status) {
    if (status === 'pending') return 'status-pending';
    if (status === 'in_progress') return 'status-in_progress';
    if (status === 'ready') return 'status-ready';
    if (status === 'cancelled') return 'status-cancelled';
    if (status === 'completed') return 'status-completed';
    return 'status-pending';
}

function getStatusLabel(status, fallback) {
    return state.statuses?.[status] || fallback || status;
}

function buildActionButtons(order) {
    const buttons = [];

    if (order.status === 'pending') {
        buttons.push('<button class="action-btn take" data-action="in_progress">Tomar pedido</button>');
    }

    if (order.status === 'in_progress') {
        buttons.push('<button class="action-btn ready" data-action="ready">Marcar listo</button>');
    }

    if (order.status === 'pending' || order.status === 'in_progress' || order.status === 'ready') {
        buttons.push('<button class="action-btn cancel" data-action="cancelled">Cancelar</button>');
    }

    return buttons.join('');
}

function renderOrders() {
    if (!Array.isArray(state.orders) || state.orders.length === 0) {
        ordersList.innerHTML = `
            <div class="empty-state">
                <div>
                    <strong>No hay pedidos activos</strong><br>
                    Los pedidos de clientes apareceran aqui en tiempo real.
                </div>
            </div>
        `;
        return;
    }

    const cards = state.orders.map((order) => {
        const ingredientTags = (order.contents || [])
            .map((line) => `<li>${escapeHtml(line)}</li>`)
            .join('');

        const assigned = order.assignedName
            ? `<div><strong>Tomado por:</strong> ${escapeHtml(order.assignedName)}</div>`
            : '<div><strong>Tomado por:</strong> Sin asignar</div>';

        return `
            <article class="order-card" data-order-id="${Number(order.id)}">
                <div class="order-head">
                    <h3>#${Number(order.id)} - ${escapeHtml(order.recipeLabel || 'Pedido')}</h3>
                    <span class="status-badge ${getStatusClass(order.status)}">${escapeHtml(getStatusLabel(order.status, order.statusLabel))}</span>
                </div>
                <div class="order-meta">
                    <div><strong>Cliente:</strong> ${escapeHtml(order.customerName || 'Cliente')}</div>
                    <div><strong>Cantidad:</strong> ${Number(order.quantity || 1)}</div>
                    <div><strong>Total:</strong> $${formatMoney(order.totalPrice)}</div>
                    ${assigned}
                </div>
                <ul class="ingredients-list">${ingredientTags || '<li>Sin contenido</li>'}</ul>
                <div class="order-actions">${buildActionButtons(order)}</div>
            </article>
        `;
    });

    ordersList.innerHTML = cards.join('');
}

function renderSummary() {
    societyBalanceEl.textContent = `$${formatMoney(state.societyBalance)}`;
    ordersCountEl.textContent = String(state.orders.length);

    const lowStock = Object.values(state.stock || {}).filter((amount) => Number(amount) <= 5).length;
    lowStockCountEl.textContent = String(lowStock);
}

function render() {
    renderSummary();
    renderOrders();
}

function openUi(payload) {
    state.orders = payload.orders || [];
    state.stock = payload.stock || {};
    state.societyBalance = payload.societyBalance || 0;
    state.statuses = payload.statuses || {};
    app.classList.remove('hidden');
    render();
}

function updateUi(payload) {
    state.orders = payload.orders || [];
    state.stock = payload.stock || {};
    state.societyBalance = payload.societyBalance || 0;
    state.statuses = payload.statuses || state.statuses || {};
    render();
}

function closeUi() {
    app.classList.add('hidden');
}

window.addEventListener('message', (event) => {
    const { action, ...payload } = event.data || {};

    if (action === 'open') {
        openUi(payload);
        return;
    }

    if (action === 'updateData') {
        updateUi(payload);
        return;
    }

    if (action === 'close') {
        closeUi();
    }
});

ordersList.addEventListener('click', (event) => {
    const button = event.target.closest('button[data-action]');
    if (!button) {
        return;
    }

    const card = button.closest('.order-card');
    if (!card) {
        return;
    }

    const orderId = Number(card.dataset.orderId);
    const status = button.dataset.action;
    postNui('updateOrderStatus', { orderId, status });
});

refreshBtn.addEventListener('click', () => {
    postNui('requestRefresh');
});

closeBtn.addEventListener('click', () => {
    postNui('close');
});

window.addEventListener('keydown', (event) => {
    if (event.key === 'Escape') {
        postNui('close');
    }
});
