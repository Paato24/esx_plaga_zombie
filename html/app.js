const appState = {
    open: false,
    route: 'overview',
    context: {},
    data: null,
    staticData: null,
    createDraftPoints: []
};

const tabNames = [
    'overview',
    'members',
    'ranks',
    'points',
    'assets',
    'missions',
    'processing',
    'armory',
    'invites',
    'logs'
];

function getResourceName() {
    if (typeof GetParentResourceName === 'function') {
        return GetParentResourceName();
    }
    return 'esx_org_hub';
}

async function postNui(endpoint, payload) {
    const response = await fetch(`https://${getResourceName()}/${endpoint}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(payload || {})
    });

    return response.json();
}

function setStatus(message, ok) {
    const el = document.getElementById('status-message');
    el.textContent = message || 'Listo.';
    el.classList.remove('ok');
    el.classList.remove('error');

    if (ok === true) {
        el.classList.add('ok');
    } else if (ok === false) {
        el.classList.add('error');
    }
}

function formatMoney(value) {
    const amount = Number(value || 0);
    return `$${amount.toLocaleString('es-ES')}`;
}

function formatDate(value) {
    if (!value) return '-';
    const date = new Date(value);
    if (Number.isNaN(date.getTime())) return String(value);
    return date.toLocaleString('es-ES');
}

function escapeHtml(input) {
    return String(input ?? '')
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
}

function isMember() {
    return Boolean(appState.data && appState.data.membership);
}

function hasPermission(permissionKey) {
    const membership = appState.data?.membership;
    if (!membership) return false;
    if (membership.isOwner) return true;
    return Boolean(membership.permissions && membership.permissions[permissionKey] === true);
}

function getCurrentContext() {
    return appState.context || {};
}

function getContextPointType() {
    return appState.context?.pointType || '';
}

function setTab(tabName) {
    const resolvedTab = tabNames.includes(tabName) ? tabName : 'overview';
    appState.route = resolvedTab;

    for (const tab of tabNames) {
        const button = document.querySelector(`[data-click="tab"][data-tab="${tab}"]`);
        const pane = document.getElementById(`tab-${tab}`);

        if (button) button.classList.toggle('active', tab === resolvedTab);
        if (pane) pane.classList.toggle('active', tab === resolvedTab);
    }
}

function renderPermissionCheckboxes(scopeId, selectedPermissions) {
    const labels = appState.staticData?.permissionLabels || {};
    const selected = selectedPermissions || {};
    const sortedKeys = Object.keys(labels).sort();

    if (!sortedKeys.length) {
        return '<p class="muted">No hay permisos configurados.</p>';
    }

    return `
        <div class="permission-list" data-scope="${scopeId}">
            ${sortedKeys
                .map((key) => {
                    const checked = selected[key] ? 'checked' : '';
                    return `
                        <label>
                            <input type="checkbox" data-perm="${escapeHtml(key)}" ${checked}>
                            ${escapeHtml(labels[key])}
                        </label>
                    `;
                })
                .join('')}
        </div>
    `;
}

function collectPermissionsFromScope(scopeId) {
    const result = {};
    const scope = document.querySelector(`[data-scope="${scopeId}"]`);
    if (!scope) return result;

    scope.querySelectorAll('input[type="checkbox"][data-perm]').forEach((checkbox) => {
        if (checkbox.checked) {
            const key = checkbox.getAttribute('data-perm');
            if (key) result[key] = true;
        }
    });

    return result;
}

function renderPendingInvitesTable(invites) {
    const rows = invites || [];
    if (!rows.length) {
        return '<p class="muted">No tienes invitaciones pendientes.</p>';
    }

    return `
        <table>
            <thead>
                <tr>
                    <th>Organizacion</th>
                    <th>Tipo</th>
                    <th>Expira</th>
                    <th>Accion</th>
                </tr>
            </thead>
            <tbody>
                ${rows
                    .map((invite) => {
                        return `
                            <tr>
                                <td>${escapeHtml(invite.org_name)} [${escapeHtml(invite.org_tag)}]</td>
                                <td>${escapeHtml(invite.org_type)}</td>
                                <td>${escapeHtml(formatDate(invite.expires_at))}</td>
                                <td class="inline-actions">
                                    <button class="success tiny" data-click="respond-invite" data-id="${invite.id}" data-accept="1">Aceptar</button>
                                    <button class="danger tiny" data-click="respond-invite" data-id="${invite.id}" data-accept="0">Rechazar</button>
                                </td>
                            </tr>
                        `;
                    })
                    .join('')}
            </tbody>
        </table>
    `;
}

function renderCreateDraftPointsTable() {
    const rows = appState.createDraftPoints || [];
    if (!rows.length) {
        return '<p class="muted">No hay puntos iniciales personalizados capturados.</p>';
    }

    return `
        <table>
            <thead>
                <tr>
                    <th>#</th>
                    <th>Tipo</th>
                    <th>Coords</th>
                    <th>Radio</th>
                    <th>Accion</th>
                </tr>
            </thead>
            <tbody>
                ${rows
                    .map((point, index) => {
                        const coords = point.coords || {};
                        return `
                            <tr>
                                <td>${index + 1}</td>
                                <td>${escapeHtml(point.pointType || '')}</td>
                                <td class="code">${Number(coords.x || 0).toFixed(2)}, ${Number(coords.y || 0).toFixed(2)}, ${Number(
                          coords.z || 0
                      ).toFixed(2)}</td>
                                <td>${Number(point.radius || 2.0).toFixed(1)}</td>
                                <td>
                                    <button class="tiny danger" data-click="remove-create-point" data-index="${index + 1}">Quitar</button>
                                </td>
                            </tr>
                        `;
                    })
                    .join('')}
            </tbody>
        </table>
    `;
}

function renderOverview() {
    const target = document.getElementById('tab-overview');
    const membership = appState.data?.membership;
    const org = appState.data?.org;

    if (!membership) {
        const options = appState.data?.createOptions || [];
        const optionHtml = options
            .map((entry) => {
                return `
                    <option value="${escapeHtml(entry.type)}">
                        ${escapeHtml(entry.label)} - ${formatMoney(entry.createPrice)} - max ${entry.maxMembers}
                    </option>
                `;
            })
            .join('');

        const pointTypes = appState.staticData?.pointTypes || {};
        const pointTypeOptions = Object.keys(pointTypes)
            .sort()
            .map((pointType) => {
                return `<option value="${escapeHtml(pointType)}">${escapeHtml(pointTypes[pointType].label || pointType)}</option>`;
            })
            .join('');

        target.innerHTML = `
            <h2>Crear organizacion</h2>
            <p class="muted">Abre este menu desde el marcador de registro para crear tu banda, mafia o cartel.</p>
            <div class="card">
                <div class="row">
                    <div>
                        <label>Tipo</label><br>
                        <select id="create-org-type">${optionHtml}</select>
                    </div>
                    <div>
                        <label>Nombre</label><br>
                        <input id="create-org-name" maxlength="32" placeholder="Nombre de la org">
                    </div>
                    <div>
                        <label>Tag</label><br>
                        <input id="create-org-tag" maxlength="6" placeholder="TAG">
                    </div>
                    <button data-click="create-org" class="primary">Crear organizacion</button>
                </div>
            </div>

            <div class="card">
                <h3>Puntos iniciales personalizados (opcional)</h3>
                <p class="muted">Pulsa capturar para guardar tu posicion actual como punto inicial antes de crear.</p>
                <div class="row">
                    <select id="create-point-type">${pointTypeOptions}</select>
                    <button data-click="capture-create-point" class="primary">Capturar punto actual</button>
                    <button data-click="clear-create-points" class="warning">Limpiar todos</button>
                </div>
                <div class="row">
                    <input id="create-point-x" placeholder="X manual">
                    <input id="create-point-y" placeholder="Y manual">
                    <input id="create-point-z" placeholder="Z manual">
                    <input id="create-point-h" placeholder="Heading" value="0">
                    <input id="create-point-r" placeholder="Radio" value="2.0">
                    <button data-click="add-manual-create-point">Agregar manual</button>
                </div>
                ${renderCreateDraftPointsTable()}
            </div>

            <h3>Invitaciones pendientes</h3>
            ${renderPendingInvitesTable(appState.data?.pendingInvites)}
        `;
        return;
    }

    target.innerHTML = `
        <h2>${escapeHtml(org?.name || membership.orgName)} [${escapeHtml(org?.tag || membership.orgTag)}]</h2>
        <div class="card-grid">
            <div class="card">
                <h3>Tipo</h3>
                <p>${escapeHtml(org?.type || membership.orgType)}</p>
            </div>
            <div class="card">
                <h3>Nivel</h3>
                <p>${org?.level || membership.level}</p>
            </div>
            <div class="card">
                <h3>XP</h3>
                <p>${org?.xp || membership.xp}</p>
            </div>
            <div class="card">
                <h3>Fondos</h3>
                <p>${formatMoney(org?.funds || membership.funds)}</p>
            </div>
            <div class="card">
                <h3>Miembros</h3>
                <p>${org?.memberCount || 0} / ${org?.maxMembers || membership.maxMembers || 0}</p>
            </div>
            <div class="card">
                <h3>Tu rango</h3>
                <p>${escapeHtml(membership.rankName)}</p>
            </div>
        </div>

        <div class="card">
            <h3>Fondos de organizacion</h3>
            <div class="row">
                <input id="funds-amount" type="number" min="1" placeholder="Cantidad">
                <button data-click="deposit-funds" class="success">Depositar</button>
                <button data-click="withdraw-funds" class="warning">Retirar</button>
            </div>
            <p class="hint">Estas acciones requieren marcador boss/organization.</p>
        </div>

        ${
            membership.isOwner
                ? `
            <div class="card">
                <h3>Transferir liderazgo</h3>
                <div class="row">
                    <input id="transfer-owner-identifier" placeholder="Identifier del miembro">
                    <button data-click="transfer-ownership" class="warning">Transferir</button>
                </div>
            </div>
        `
                : ''
        }

        <div class="card">
            <h3>Acciones administrativas</h3>
            <div class="row">
                <button data-click="leave-org" class="danger">Salir de la organizacion</button>
                ${
                    membership.isOwner
                        ? '<button data-click="dissolve-org" class="danger">Disolver organizacion</button>'
                        : ''
                }
            </div>
        </div>
    `;
}

function renderMembers() {
    const target = document.getElementById('tab-members');
    if (!isMember()) {
        target.innerHTML = '<p class="muted">Debes pertenecer a una organizacion.</p>';
        return;
    }

    const members = appState.data?.members || [];
    const playerIdentifier = appState.data?.player?.identifier;
    const canManage = hasPermission('manage_members');
    const isOwner = Boolean(appState.data?.membership?.isOwner);

    target.innerHTML = `
        <h2>Miembros</h2>
        <table>
            <thead>
                <tr>
                    <th>Nombre</th>
                    <th>Rango</th>
                    <th>Peso</th>
                    <th>Online</th>
                    <th>Accion</th>
                </tr>
            </thead>
            <tbody>
                ${
                    members.length
                        ? members
                              .map((member) => {
                                  const encodedIdentifier = encodeURIComponent(member.identifier);
                                  const isSelf = member.identifier === playerIdentifier;
                                  return `
                                      <tr>
                                          <td>${escapeHtml(member.name)}</td>
                                          <td>${escapeHtml(member.rank_name)}</td>
                                          <td>${member.rank_weight}</td>
                                          <td>${member.isOnline ? 'Si' : 'No'}</td>
                                          <td class="inline-actions">
                                              ${
                                                  canManage && !isSelf
                                                      ? `
                                                  <button class="tiny" data-click="promote-member" data-identifier="${encodedIdentifier}">Ascender</button>
                                                  <button class="tiny warning" data-click="demote-member" data-identifier="${encodedIdentifier}">Degradar</button>
                                                  <button class="tiny danger" data-click="kick-member" data-identifier="${encodedIdentifier}">Expulsar</button>
                                              `
                                                      : ''
                                              }
                                              ${
                                                  isOwner && !isSelf
                                                      ? `<button class="tiny warning" data-click="transfer-ownership-inline" data-identifier="${encodedIdentifier}">Transferir</button>`
                                                      : ''
                                              }
                                              ${
                                                  !canManage && !(isOwner && !isSelf)
                                                      ? '<span class="muted">-</span>'
                                                      : ''
                                              }
                                          </td>
                                      </tr>
                                  `;
                              })
                              .join('')
                        : '<tr><td colspan="5" class="muted">Sin miembros.</td></tr>'
                }
            </tbody>
        </table>
        <p class="hint">Gestion de miembros disponible en punto boss/organization.</p>
    `;
}

function renderRanks() {
    const target = document.getElementById('tab-ranks');
    if (!isMember()) {
        target.innerHTML = '<p class="muted">Debes pertenecer a una organizacion.</p>';
        return;
    }

    const ranks = appState.data?.ranks || [];
    const canManage = hasPermission('manage_ranks');

    target.innerHTML = `
        <h2>Rangos</h2>
        ${
            canManage
                ? `
            <div class="card">
                <h3>Crear rango</h3>
                <div class="row">
                    <input id="new-rank-name" maxlength="24" placeholder="Nombre">
                    <input id="new-rank-weight" type="number" min="1" max="100" placeholder="Peso">
                    <button data-click="create-rank" class="primary">Crear</button>
                </div>
                ${renderPermissionCheckboxes('create-rank', {})}
            </div>
        `
                : '<p class="muted">Solo lectura: no tienes permiso para gestionar rangos.</p>'
        }

        <table>
            <thead>
                <tr>
                    <th>Nombre</th>
                    <th>Peso</th>
                    <th>Permisos</th>
                    <th>Accion</th>
                </tr>
            </thead>
            <tbody>
                ${
                    ranks.length
                        ? ranks
                              .map((rank) => {
                                  const perms = Object.keys(rank.permissions || {})
                                      .filter((key) => rank.permissions[key] === true)
                                      .join(', ');

                                  return `
                                      <tr>
                                          <td>${escapeHtml(rank.name)}</td>
                                          <td>${rank.weight}</td>
                                          <td class="muted">${escapeHtml(perms || 'Sin permisos')}</td>
                                          <td class="inline-actions">
                                              ${
                                                  canManage
                                                      ? `
                                                  <button class="tiny" data-click="edit-rank" data-rank-id="${rank.id}">Editar</button>
                                                  <button class="tiny danger" data-click="delete-rank" data-rank-id="${rank.id}">Eliminar</button>
                                              `
                                                      : '<span class="muted">-</span>'
                                              }
                                          </td>
                                      </tr>
                                  `;
                              })
                              .join('')
                        : '<tr><td colspan="4" class="muted">No hay rangos.</td></tr>'
                }
            </tbody>
        </table>
        <p class="hint">Gestion de rangos disponible en punto boss/organization.</p>
    `;
}

function renderPoints() {
    const target = document.getElementById('tab-points');
    if (!isMember()) {
        target.innerHTML = '<p class="muted">Debes pertenecer a una organizacion.</p>';
        return;
    }

    const points = appState.data?.points || [];
    const pointTypes = appState.staticData?.pointTypes || {};
    const canManage = hasPermission('manage_points');

    const typeOptions = Object.keys(pointTypes)
        .sort()
        .map((pointType) => {
            return `<option value="${escapeHtml(pointType)}">${escapeHtml(pointTypes[pointType].label || pointType)}</option>`;
        })
        .join('');

    const sortedPoints = [...points].sort((a, b) => {
        if (a.point_type === b.point_type) return Number(a.id) - Number(b.id);
        return String(a.point_type).localeCompare(String(b.point_type));
    });

    const rows = sortedPoints.length
        ? sortedPoints
              .map((point) => {
                  return `
                    <tr>
                        <td>${point.id}</td>
                        <td>${escapeHtml(point.point_type)}</td>
                        <td>${escapeHtml(point.label || '')}</td>
                        <td class="code">${Number(point.x).toFixed(2)}, ${Number(point.y).toFixed(2)}, ${Number(point.z).toFixed(2)}</td>
                        <td>${Number(point.radius || 2.0).toFixed(1)}</td>
                        <td class="inline-actions">
                            ${
                                canManage
                                    ? `
                                <button class="tiny primary" data-click="move-point" data-point-id="${point.id}" data-point-type="${escapeHtml(
                                          point.point_type
                                      )}">Mover aqui</button>
                                <button class="tiny danger" data-click="delete-point" data-point-id="${point.id}">Eliminar</button>
                            `
                                    : '<span class="muted">-</span>'
                            }
                        </td>
                    </tr>
                `;
              })
              .join('')
        : '<tr><td colspan="6" class="muted">No hay puntos definidos.</td></tr>';

    target.innerHTML = `
        <h2>Puntos de organizacion</h2>
        ${
            canManage
                ? `
            <div class="card">
                <h3>Agregar punto en tu posicion actual</h3>
                <div class="row">
                    <select id="point-new-type">${typeOptions}</select>
                    <input id="point-new-radius" type="number" min="1.5" max="5.0" step="0.1" placeholder="Radio (opcional)">
                    <button data-click="set-point" class="primary">Agregar punto</button>
                </div>
            </div>
        `
                : ''
        }
        <table>
            <thead>
                <tr>
                    <th>ID</th>
                    <th>Tipo</th>
                    <th>Label</th>
                    <th>Ubicacion</th>
                    <th>Radio</th>
                    <th>Accion</th>
                </tr>
            </thead>
            <tbody>${rows}</tbody>
        </table>
        <p class="hint">Para actualizar puntos debes abrir este menu desde boss/organization.</p>
    `;
}

function renderAssets() {
    const target = document.getElementById('tab-assets');
    if (!isMember()) {
        target.innerHTML = '<p class="muted">Debes pertenecer a una organizacion.</p>';
        return;
    }

    const canManageAssets = hasPermission('manage_assets');
    const canGarage = hasPermission('use_garage');
    const canHangar = hasPermission('use_hangar');
    const contextType = getContextPointType();
    const catalog = appState.staticData?.assetCatalog || {};
    const assets = appState.data?.assets || [];
    const ownedCountByModel = {};
    assets.forEach((asset) => {
        const key = `${asset.asset_type}:${asset.model}`;
        ownedCountByModel[key] = (ownedCountByModel[key] || 0) + 1;
    });

    const vehicleCatalog = (catalog.vehicle || [])
        .map((entry) => {
            const modelKey = `vehicle:${entry.model}`;
            const owned = ownedCountByModel[modelKey] || 0;
            const maxOwned = Number(entry.maxOwned || 0);
            const maxLabel = maxOwned > 0 ? `${owned}/${maxOwned}` : `${owned}/sin limite`;
            return `
                <tr>
                    <td>${escapeHtml(entry.label)}</td>
                    <td>${escapeHtml(entry.model)}</td>
                    <td>${entry.requiredLevel}</td>
                    <td>${entry.requiredRankWeight}</td>
                    <td>${formatMoney(entry.price)}</td>
                    <td>${escapeHtml(maxLabel)}</td>
                    <td>
                        <button class="tiny primary" data-click="buy-asset" data-asset-type="vehicle" data-model="${escapeHtml(entry.model)}" ${
                            canManageAssets ? '' : 'disabled'
                        }>Comprar</button>
                    </td>
                </tr>
            `;
        })
        .join('');

    const aircraftCatalog = (catalog.aircraft || [])
        .map((entry) => {
            const modelKey = `aircraft:${entry.model}`;
            const owned = ownedCountByModel[modelKey] || 0;
            const maxOwned = Number(entry.maxOwned || 0);
            const maxLabel = maxOwned > 0 ? `${owned}/${maxOwned}` : `${owned}/sin limite`;
            return `
                <tr>
                    <td>${escapeHtml(entry.label)}</td>
                    <td>${escapeHtml(entry.model)}</td>
                    <td>${entry.requiredLevel}</td>
                    <td>${entry.requiredRankWeight}</td>
                    <td>${formatMoney(entry.price)}</td>
                    <td>${escapeHtml(maxLabel)}</td>
                    <td>
                        <button class="tiny primary" data-click="buy-asset" data-asset-type="aircraft" data-model="${escapeHtml(entry.model)}" ${
                            canManageAssets ? '' : 'disabled'
                        }>Comprar</button>
                    </td>
                </tr>
            `;
        })
        .join('');

    const ownedRows = assets.length
        ? assets
              .map((asset) => {
                  const canSpawn =
                      (asset.asset_type === 'vehicle' && canGarage) ||
                      (asset.asset_type === 'aircraft' && canHangar);
                  return `
                    <tr>
                        <td>${escapeHtml(asset.label)}</td>
                        <td>${escapeHtml(asset.asset_type)}</td>
                        <td>${escapeHtml(asset.plate)}</td>
                        <td>${asset.stored === 1 ? 'Guardado' : 'Desplegado'}</td>
                        <td>${asset.required_level}</td>
                        <td>${asset.required_rank_weight}</td>
                        <td class="inline-actions">
                            ${
                                canSpawn && asset.stored === 1
                                    ? `<button class="tiny success" data-click="spawn-asset" data-asset-id="${asset.id}">Sacar</button>`
                                    : '<span class="muted">-</span>'
                            }
                        </td>
                    </tr>
                `;
              })
              .join('')
        : '<tr><td colspan="7" class="muted">No hay activos comprados.</td></tr>';

    target.innerHTML = `
        <h2>Activos de organizacion</h2>
        <p class="hint">Contexto actual: <b>${escapeHtml(contextType || 'ninguno')}</b>. Para comprar/sacar/guardar usa marcador garage u hangar.</p>

        <div class="card">
            <h3>Guardar activo actual</h3>
            <button data-click="store-current-asset" class="warning">Guardar vehiculo/aeronave actual</button>
        </div>

        <div class="card">
            <h3>Catalogo vehiculos</h3>
            <table>
                <thead>
                    <tr><th>Label</th><th>Modelo</th><th>Nivel</th><th>Peso rango</th><th>Precio</th><th>Stock org</th><th>Accion</th></tr>
                </thead>
                <tbody>${vehicleCatalog || '<tr><td colspan="7" class="muted">Sin catalogo.</td></tr>'}</tbody>
            </table>
        </div>

        <div class="card">
            <h3>Catalogo aeronaves</h3>
            <table>
                <thead>
                    <tr><th>Label</th><th>Modelo</th><th>Nivel</th><th>Peso rango</th><th>Precio</th><th>Stock org</th><th>Accion</th></tr>
                </thead>
                <tbody>${aircraftCatalog || '<tr><td colspan="7" class="muted">Sin catalogo.</td></tr>'}</tbody>
            </table>
        </div>

        <div class="card">
            <h3>Activos comprados</h3>
            <table>
                <thead>
                    <tr><th>Label</th><th>Tipo</th><th>Placa</th><th>Estado</th><th>Nivel</th><th>Rango</th><th>Accion</th></tr>
                </thead>
                <tbody>${ownedRows}</tbody>
            </table>
        </div>
    `;
}

function renderMissions() {
    const target = document.getElementById('tab-missions');
    if (!isMember()) {
        target.innerHTML = '<p class="muted">Debes pertenecer a una organizacion.</p>';
        return;
    }

    const missions = appState.staticData?.missions || [];
    const canUse = hasPermission('use_missions');
    const activeMission = appState.data?.activeMission;

    target.innerHTML = `
        <h2>Misiones</h2>
        ${
            activeMission
                ? `
            <div class="card">
                <h3>Mision activa: ${escapeHtml(activeMission.label || activeMission.missionId)}</h3>
                <p>Destino: <span class="code">${Number(activeMission.target.x).toFixed(2)}, ${Number(
                      activeMission.target.y
                  ).toFixed(2)}, ${Number(activeMission.target.z).toFixed(2)}</span></p>
                <p>Participantes: ${activeMission.participantsCount || 0}</p>
                <div class="row">
                    ${
                        !activeMission.isParticipant
                            ? '<button class="success" data-click="join-mission">Unirme a la mision</button>'
                            : '<button class="warning" data-click="leave-mission">Salir de la mision</button>'
                    }
                    <button class="warning" data-click="cancel-mission">Cancelar mision</button>
                </div>
                <p class="hint">Ve al marcador verde y pulsa E para completarla.</p>
            </div>
        `
                : '<p class="muted">No hay mision activa para tu organizacion.</p>'
        }

        <div class="card">
            <h3>Misiones disponibles</h3>
            <table>
                <thead>
                    <tr><th>ID</th><th>Label</th><th>Nivel</th><th>Rango</th><th>XP</th><th>Fondos Org</th><th>Accion</th></tr>
                </thead>
                <tbody>
                    ${
                        missions.length
                            ? missions
                                  .map((mission) => {
                                      return `
                                        <tr>
                                            <td>${escapeHtml(mission.id)}</td>
                                            <td>${escapeHtml(mission.label)}</td>
                                            <td>${mission.requiredLevel}</td>
                                            <td>${mission.requiredRankWeight}</td>
                                            <td>${mission.xpGain}</td>
                                            <td>${formatMoney(mission.orgFundsReward)}</td>
                                            <td>
                                                <button class="tiny primary" data-click="start-mission" data-mission-id="${escapeHtml(
                                                    mission.id
                                                )}" ${canUse ? '' : 'disabled'}>Iniciar</button>
                                            </td>
                                        </tr>
                                    `;
                                  })
                                  .join('')
                            : '<tr><td colspan="7" class="muted">No hay misiones configuradas.</td></tr>'
                    }
                </tbody>
            </table>
            <p class="hint">Iniciar/unirte a mision requiere estar en el punto mission.</p>
        </div>
    `;
}

function renderProcessing() {
    const target = document.getElementById('tab-processing');
    if (!isMember()) {
        target.innerHTML = '<p class="muted">Debes pertenecer a una organizacion.</p>';
        return;
    }

    const recipes = appState.staticData?.drugRecipes || [];
    const canProcess = hasPermission('use_drugs');

    target.innerHTML = `
        <h2>Procesamiento de drogas</h2>
        <table>
            <thead>
                <tr><th>Receta</th><th>Inputs</th><th>Outputs</th><th>Nivel</th><th>Rango</th><th>XP</th><th>Costo base</th><th>Accion</th></tr>
            </thead>
            <tbody>
                ${
                    recipes.length
                        ? recipes
                              .map((recipe) => {
                                  const inputs = (recipe.inputs || [])
                                      .map((entry) => `${entry.item} x${entry.count}`)
                                      .join(', ');
                                  const outputs = (recipe.outputs || [])
                                      .map((entry) => `${entry.item} x${entry.count}`)
                                      .join(', ');
                                  return `
                                    <tr>
                                        <td>${escapeHtml(recipe.label)}</td>
                                        <td class="code">${escapeHtml(inputs)}</td>
                                        <td class="code">${escapeHtml(outputs)}</td>
                                        <td>${recipe.requiredLevel}</td>
                                        <td>${recipe.requiredRankWeight}</td>
                                        <td>${recipe.xpGain}</td>
                                        <td>${formatMoney(recipe.processFee || appState.staticData?.economy?.DefaultDrugProcessFee || 0)}</td>
                                        <td>
                                            <button class="tiny primary" data-click="process-recipe" data-recipe-id="${escapeHtml(
                                                recipe.id
                                            )}" ${canProcess ? '' : 'disabled'}>Procesar</button>
                                        </td>
                                    </tr>
                                `;
                              })
                              .join('')
                        : '<tr><td colspan="8" class="muted">No hay recetas configuradas.</td></tr>'
                }
            </tbody>
        </table>
        <p class="hint">Para procesar debes estar en el punto drug_process.</p>
    `;
}

function renderArmory() {
    const target = document.getElementById('tab-armory');
    if (!isMember()) {
        target.innerHTML = '<p class="muted">Debes pertenecer a una organizacion.</p>';
        return;
    }

    const shop = appState.staticData?.weaponShop || [];
    const canBuy = hasPermission('use_weapons');

    target.innerHTML = `
        <h2>Tienda de armas</h2>
        <table>
            <thead>
                <tr><th>Item</th><th>Label</th><th>Nivel</th><th>Rango</th><th>Precio base</th><th>XP</th><th>Accion</th></tr>
            </thead>
            <tbody>
                ${
                    shop.length
                        ? shop
                              .map((entry) => {
                                  return `
                                    <tr>
                                        <td class="code">${escapeHtml(entry.item)}</td>
                                        <td>${escapeHtml(entry.label)}</td>
                                        <td>${entry.requiredLevel}</td>
                                        <td>${entry.requiredRankWeight}</td>
                                        <td>${formatMoney(entry.price)}</td>
                                        <td>${entry.xpGain}</td>
                                        <td>
                                            <button class="tiny primary" data-click="buy-weapon" data-item="${escapeHtml(
                                                entry.item
                                            )}" ${canBuy ? '' : 'disabled'}>Comprar</button>
                                        </td>
                                    </tr>
                                `;
                              })
                              .join('')
                        : '<tr><td colspan="7" class="muted">No hay items configurados.</td></tr>'
                }
            </tbody>
        </table>
        <p class="hint">Para comprar debes estar en el punto weapon_shop.</p>
    `;
}

function renderInvites() {
    const target = document.getElementById('tab-invites');
    const membership = appState.data?.membership;
    const canManageInvites = hasPermission('manage_invites');
    const orgInvites = appState.data?.orgInvites || [];

    target.innerHTML = `
        <h2>Invitaciones</h2>
        ${
            membership && canManageInvites
                ? `
            <div class="card">
                <h3>Invitar jugador por ID</h3>
                <div class="row">
                    <input id="invite-target-id" type="number" min="1" placeholder="ID jugador">
                    <button data-click="invite-player" class="primary">Enviar invitacion</button>
                </div>
                <p class="hint">Invitar requiere punto invite, boss o organization.</p>
            </div>

            <div class="card">
                <h3>Invitaciones enviadas por tu organizacion</h3>
                ${
                    orgInvites.length
                        ? `
                    <table>
                        <thead>
                            <tr><th>Nombre</th><th>Identifier</th><th>Creada</th><th>Expira</th></tr>
                        </thead>
                        <tbody>
                            ${orgInvites
                                .map((entry) => {
                                    return `
                                        <tr>
                                            <td>${escapeHtml(entry.target_name)}</td>
                                            <td class="code">${escapeHtml(entry.target_identifier)}</td>
                                            <td>${escapeHtml(formatDate(entry.created_at))}</td>
                                            <td>${escapeHtml(formatDate(entry.expires_at))}</td>
                                        </tr>
                                    `;
                                })
                                .join('')}
                        </tbody>
                    </table>
                `
                        : '<p class="muted">No hay invitaciones enviadas pendientes.</p>'
                }
            </div>
        `
                : ''
        }

        <div class="card">
            <h3>Tus invitaciones pendientes</h3>
            ${renderPendingInvitesTable(appState.data?.pendingInvites)}
        </div>
    `;
}

function formatLogDetails(details) {
    if (!details) return '-';
    try {
        const serialized = JSON.stringify(details);
        return serialized.length > 160 ? `${serialized.slice(0, 160)}...` : serialized;
    } catch (error) {
        return String(details);
    }
}

function renderLogs() {
    const target = document.getElementById('tab-logs');
    if (!isMember()) {
        target.innerHTML = '<p class="muted">Debes pertenecer a una organizacion.</p>';
        return;
    }

    const logs = appState.data?.logs || [];
    if (!logs.length) {
        target.innerHTML = '<p class="muted">No hay logs visibles para tu rango.</p>';
        return;
    }

    target.innerHTML = `
        <h2>Historial de organizacion</h2>
        <table>
            <thead>
                <tr>
                    <th>ID</th>
                    <th>Fecha</th>
                    <th>Actor</th>
                    <th>Accion</th>
                    <th>Detalles</th>
                </tr>
            </thead>
            <tbody>
                ${logs
                    .map((entry) => {
                        return `
                            <tr>
                                <td>${entry.id}</td>
                                <td>${escapeHtml(formatDate(entry.created_at))}</td>
                                <td>${escapeHtml(entry.actor_name || entry.actor_identifier || '-')}</td>
                                <td>${escapeHtml(entry.action || '-')}</td>
                                <td class="code">${escapeHtml(formatLogDetails(entry.details))}</td>
                            </tr>
                        `;
                    })
                    .join('')}
            </tbody>
        </table>
    `;
}

function renderAll() {
    if (!appState.data) return;

    const membership = appState.data.membership;
    const subtitle = document.getElementById('header-subtitle');
    if (membership) {
        subtitle.textContent = `${membership.orgName} [${membership.orgTag}] - ${membership.rankName}`;
    } else {
        subtitle.textContent = 'Sin organizacion activa';
    }

    renderOverview();
    renderMembers();
    renderRanks();
    renderPoints();
    renderAssets();
    renderMissions();
    renderProcessing();
    renderArmory();
    renderInvites();
    renderLogs();
    setTab(appState.route);
}

function applySyncLite(sync) {
    if (!appState.data || !sync) return;
    appState.data.membership = sync.membership || null;
    appState.data.pendingInvites = sync.pendingInvites || [];
    appState.data.points = sync.points || [];
    appState.data.activeMission = sync.activeMission || null;

    if (!sync.membership) {
        appState.data.org = null;
        appState.data.members = [];
        appState.data.ranks = [];
        appState.data.assets = [];
        appState.data.orgInvites = [];
        appState.data.logs = [];
    }

    renderAll();
}

async function performAction(action, payload, customContext) {
    try {
        const response = await postNui('performAction', {
            action,
            payload: payload || {},
            context: customContext || getCurrentContext()
        });

        if (response?.state) {
            appState.data = response.state;
            renderAll();
        }

        if (response?.sync) {
            applySyncLite(response.sync);
        }

        if (Array.isArray(response?.draftPoints)) {
            appState.createDraftPoints = response.draftPoints;
            renderAll();
        }

        setStatus(response?.message || 'Accion ejecutada.', response?.ok === true);
        return response;
    } catch (error) {
        setStatus(`Error NUI: ${error?.message || error}`, false);
        return { ok: false, message: 'Error de comunicacion.' };
    }
}

async function closePanel() {
    appState.open = false;
    document.getElementById('app').classList.add('hidden');
    await postNui('close', {});
}

async function handleClick(event) {
    const button = event.target.closest('[data-click]');
    if (!button) return;

    const action = button.getAttribute('data-click');
    if (!action) return;

    if (action === 'tab') {
        setTab(button.getAttribute('data-tab'));
        return;
    }

    if (action === 'create-org') {
        const orgType = document.getElementById('create-org-type')?.value || '';
        const name = document.getElementById('create-org-name')?.value || '';
        const tag = document.getElementById('create-org-tag')?.value || '';
        await performAction('createOrg', { orgType, name, tag });
        return;
    }

    if (action === 'capture-create-point') {
        const pointType = document.getElementById('create-point-type')?.value || '';
        await performAction('captureCreatePoint', { pointType });
        return;
    }

    if (action === 'add-manual-create-point') {
        const pointType = document.getElementById('create-point-type')?.value || '';
        const x = Number(document.getElementById('create-point-x')?.value || NaN);
        const y = Number(document.getElementById('create-point-y')?.value || NaN);
        const z = Number(document.getElementById('create-point-z')?.value || NaN);
        const heading = Number(document.getElementById('create-point-h')?.value || 0);
        const radius = Number(document.getElementById('create-point-r')?.value || 2.0);
        await performAction('addCreatePointManual', { pointType, x, y, z, heading, radius });
        return;
    }

    if (action === 'remove-create-point') {
        const index = Number(button.getAttribute('data-index'));
        await performAction('removeCreatePointDraft', { index });
        return;
    }

    if (action === 'clear-create-points') {
        await performAction('clearCreatePointDraft', {});
        return;
    }

    if (action === 'deposit-funds') {
        const amount = Number(document.getElementById('funds-amount')?.value || 0);
        await performAction('depositFunds', { amount });
        return;
    }

    if (action === 'withdraw-funds') {
        const amount = Number(document.getElementById('funds-amount')?.value || 0);
        await performAction('withdrawFunds', { amount });
        return;
    }

    if (action === 'transfer-ownership') {
        const identifier = document.getElementById('transfer-owner-identifier')?.value || '';
        const confirmation = window.confirm('Seguro que deseas transferir el liderazgo?');
        if (confirmation) {
            await performAction('transferOwnership', { identifier });
        }
        return;
    }

    if (action === 'transfer-ownership-inline') {
        const identifier = decodeURIComponent(button.getAttribute('data-identifier') || '');
        const confirmation = window.confirm(`Transferir liderazgo a ${identifier}?`);
        if (confirmation) {
            await performAction('transferOwnership', { identifier });
        }
        return;
    }

    if (action === 'invite-player') {
        const targetId = Number(document.getElementById('invite-target-id')?.value || 0);
        await performAction('invitePlayer', { targetId });
        return;
    }

    if (action === 'respond-invite') {
        const inviteId = Number(button.getAttribute('data-id'));
        const accept = button.getAttribute('data-accept') === '1';
        await performAction('respondInvite', { inviteId, accept });
        return;
    }

    if (action === 'promote-member') {
        const identifier = decodeURIComponent(button.getAttribute('data-identifier') || '');
        await performAction('promoteMember', { identifier });
        return;
    }

    if (action === 'demote-member') {
        const identifier = decodeURIComponent(button.getAttribute('data-identifier') || '');
        await performAction('demoteMember', { identifier });
        return;
    }

    if (action === 'kick-member') {
        const identifier = decodeURIComponent(button.getAttribute('data-identifier') || '');
        const confirmation = window.confirm('Seguro que quieres expulsar a este miembro?');
        if (confirmation) {
            await performAction('kickMember', { identifier });
        }
        return;
    }

    if (action === 'create-rank') {
        const name = document.getElementById('new-rank-name')?.value || '';
        const weight = Number(document.getElementById('new-rank-weight')?.value || 0);
        const permissions = collectPermissionsFromScope('create-rank');
        await performAction('createRank', { name, weight, permissions });
        return;
    }

    if (action === 'edit-rank') {
        const rankId = Number(button.getAttribute('data-rank-id'));
        const rank = (appState.data?.ranks || []).find((entry) => Number(entry.id) === rankId);
        if (!rank) {
            setStatus('Rango no encontrado.', false);
            return;
        }

        const newName = window.prompt('Nuevo nombre de rango:', rank.name);
        if (newName === null) return;

        const newWeightRaw = window.prompt('Nuevo peso de rango (1-100):', String(rank.weight));
        if (newWeightRaw === null) return;

        const selectedPerms = Object.keys(rank.permissions || {})
            .filter((key) => rank.permissions[key] === true)
            .join(',');
        const permsRaw = window.prompt(
            'Permisos separados por coma (ej: manage_members,use_stash)',
            selectedPerms
        );
        if (permsRaw === null) return;

        const permissions = {};
        const labels = appState.staticData?.permissionLabels || {};
        permsRaw
            .split(',')
            .map((entry) => entry.trim())
            .filter((entry) => entry.length > 0)
            .forEach((entry) => {
                if (labels[entry]) {
                    permissions[entry] = true;
                }
            });

        await performAction('updateRank', {
            rankId,
            name: newName,
            weight: Number(newWeightRaw),
            permissions
        });
        return;
    }

    if (action === 'delete-rank') {
        const rankId = Number(button.getAttribute('data-rank-id'));
        const confirmation = window.confirm('Seguro que quieres eliminar este rango?');
        if (confirmation) {
            await performAction('deleteRank', { rankId });
        }
        return;
    }

    if (action === 'set-point') {
        const pointType = document.getElementById('point-new-type')?.value || '';
        const radius = Number(document.getElementById('point-new-radius')?.value || 0);
        await performAction('setPointHere', { pointType, radius: radius > 0 ? radius : undefined });
        return;
    }

    if (action === 'move-point') {
        const pointId = Number(button.getAttribute('data-point-id'));
        const pointType = button.getAttribute('data-point-type') || '';
        await performAction('setPointHere', { pointId, pointType });
        return;
    }

    if (action === 'delete-point') {
        const pointId = Number(button.getAttribute('data-point-id'));
        const confirmation = window.confirm(`Eliminar punto ID ${pointId}?`);
        if (confirmation) {
            await performAction('deletePoint', { pointId });
        }
        return;
    }

    if (action === 'buy-asset') {
        const assetType = button.getAttribute('data-asset-type') || '';
        const model = button.getAttribute('data-model') || '';
        await performAction('buyAsset', { assetType, model });
        return;
    }

    if (action === 'spawn-asset') {
        const assetId = Number(button.getAttribute('data-asset-id'));
        await performAction('spawnAsset', { assetId });
        return;
    }

    if (action === 'store-current-asset') {
        await performAction('storeCurrentAsset', {});
        return;
    }

    if (action === 'start-mission') {
        const missionId = button.getAttribute('data-mission-id') || '';
        await performAction('startMission', { missionId });
        return;
    }

    if (action === 'join-mission') {
        await performAction('joinMission', {});
        return;
    }

    if (action === 'leave-mission') {
        await performAction('leaveMission', {});
        return;
    }

    if (action === 'cancel-mission') {
        await performAction('cancelMission', {});
        return;
    }

    if (action === 'process-recipe') {
        const recipeId = button.getAttribute('data-recipe-id') || '';
        await performAction('processRecipe', { recipeId });
        return;
    }

    if (action === 'buy-weapon') {
        const item = button.getAttribute('data-item') || '';
        await performAction('buyWeapon', { item });
        return;
    }

    if (action === 'leave-org') {
        const confirmation = window.confirm('Seguro que quieres salir de la organizacion?');
        if (confirmation) {
            await performAction('leaveOrg', {});
        }
        return;
    }

    if (action === 'dissolve-org') {
        const token = window.prompt("Para confirmar escribe EXACTO: CONFIRMAR");
        if (token === null) return;
        await performAction('dissolveOrg', { confirmation: token });
    }
}

window.addEventListener('message', (event) => {
    const payload = event.data || {};
    if (!payload.action) return;

    if (payload.action === 'open') {
        appState.open = true;
        appState.route = tabNames.includes(payload.route) ? payload.route : 'overview';
        appState.context = payload.context || {};
        appState.data = payload.data || {};
        appState.staticData = payload.static || {};
        appState.createDraftPoints = payload.draftPoints || [];

        document.getElementById('app').classList.remove('hidden');
        renderAll();
        setStatus('Panel abierto.', true);
        return;
    }

    if (payload.action === 'close') {
        appState.open = false;
        document.getElementById('app').classList.add('hidden');
        return;
    }

    if (payload.action === 'setData') {
        appState.data = payload.data || appState.data;
        renderAll();
        return;
    }

    if (payload.action === 'syncLite') {
        if (Array.isArray(payload.draftPoints)) {
            appState.createDraftPoints = payload.draftPoints;
        }
        applySyncLite(payload.sync);
        return;
    }

    if (payload.action === 'setMission') {
        if (appState.data) {
            appState.data.activeMission = payload.mission || null;
            renderAll();
        }
    }
});

document.addEventListener('click', (event) => {
    handleClick(event);
});

document.getElementById('close-btn').addEventListener('click', () => {
    closePanel();
});

document.addEventListener('keyup', (event) => {
    if (event.key === 'Escape' && appState.open) {
        closePanel();
    }
});
