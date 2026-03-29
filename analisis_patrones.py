import json
from collections import defaultdict
from datetime import datetime, timedelta

with open('sorteos_export.json', encoding='utf-8') as f:
    raw = json.load(f)

# ── Preparar datos ──────────────────────────────────────────────────────────
sorteos = {}
for fecha_str, vals in raw.items():
    fecha = datetime.strptime(fecha_str, '%Y-%m-%d')
    sorteos[fecha] = {
        'maniana': vals.get('maniana'),
        'tarde':   vals.get('tarde'),
        'noche':   vals.get('noche'),
    }

fechas = sorted(sorteos.keys())

# Secuencia plana: (fecha, turno, numero)
draws = []
for f in fechas:
    s = sorteos[f]
    for turno in ['maniana', 'tarde', 'noche']:
        if s[turno] is not None:
            draws.append((f, turno, s[turno]))

# Filtrar 2026
draws_2026 = [(f, t, n) for f, t, n in draws if f.year == 2026]
fechas_2026 = [f for f in fechas if f.year == 2026]

LIBRO = {
    0:'Avión',1:'Pies',2:'Mujer',3:'Muerto',4:'Tigre',5:'Embarazada',
    6:'Elefante',7:'Navaja',8:'Conejo',9:'Hombre',10:'Anillo',11:'Perro',
    12:'Caballo',13:'Gato',14:'Boda',15:'Ratón',16:'Niña',17:'Joven',
    18:'Ángel',19:'Mariposa',20:'Espejo',21:'Pájaro',22:'Ataúd',23:'Mono',
    24:'Sapo',25:'Balanza',26:'Bandera',27:'Juego',28:'Gallo',29:'Padre',
    30:'Bolo',31:'Alacrán',32:'Culebra',33:'Carpintero',34:'Música',
    35:'Virgen',36:'Viejita',37:'Suerte',38:'Pistola',39:'Jabón',40:'Cielo',
    41:'Novia',42:'Madre',43:'Pantera',44:'Mesas',45:'Iglesia',46:'Familia',
    47:'Banco',48:'Estrella',49:'Sombra',50:'Luna nueva',51:'Policía',
    52:'Zorrillo',53:'Llanta',54:'Licor',55:'Olas',56:'Árbol',57:'Cuchillo',
    58:'Venado',59:'Selva',60:'Dragón',61:'Guerra',62:'Lagarto',63:'Coco',
    64:'Mueble',65:'Pintura',66:'Diablo',67:'Vaca',68:'Ladrón',69:'Soldado',
    70:'Oro',71:'Zapatos',72:'Arco',73:'Fuego',74:'Edificio',75:'Reina',
    76:'Palomas',77:'Humo',78:'Tienda',79:'Flores',80:'Café',81:'Rieles',
    82:'Escuela',83:'Bote',84:'Coronas',85:'Casa',86:'Reloj',87:'León',
    88:'Platos',89:'Búho',90:'Lentes',91:'Tortuga',92:'Águila',93:'Cartero',
    94:'Carro',95:'Costurera',96:'Dinero',97:'Viejito',98:'Bailes',99:'Aretes'
}

GRUPOS = {
    'Transporte':  [0, 53, 81, 83, 94],
    'Animales':    [4, 8, 11, 12, 13, 23, 24, 43, 62, 67, 87, 91, 92],
    'Familia':     [2, 9, 14, 16, 17, 29, 36, 41, 42, 46, 97],
    'Casa/Hogar':  [44, 64, 74, 85, 88],
    'Religión':    [3, 18, 22, 35, 40, 45, 66, 84],
    'Dinero':      [25, 47, 70, 96],
    'Armas':       [7, 38, 57, 61, 69],
    'Naturaleza':  [19, 21, 48, 50, 56, 59, 76, 79],
    'Oficios':     [33, 51, 68, 93, 95],
    'Bebidas':     [30, 54, 80],
}

def grupo_de(n):
    for g, nums in GRUPOS.items():
        if n in nums:
            return g
    return None

def sig(n):
    return LIBRO.get(n, '?')

# ── Equivalencias quebrado ──────────────────────────────────────────────────
EQ = {
    0:[0,1,7,4], 1:[1,0,7,4], 2:[2,5], 3:[3,8],
    4:[4,7,1,0], 5:[5,2],     6:[6,9], 7:[7,4,1,0],
    8:[8,3],     9:[9,6]
}

def es_quebrado(a, b):
    """¿Es b un quebrado (por suma) de a?"""
    suma_a = (a // 10) + (a % 10)
    sa, sb = suma_a // 10, suma_a % 10
    suma_b = (b // 10) + (b % 10)
    sb2, sb3 = suma_b // 10, suma_b % 10
    eq_sa = EQ.get(sa, [sa])
    # 010 rule
    eq_sb = [0,1,7,4,8,3] if (sb == 0 and sa > 0) else EQ.get(sb, [sb])
    eq_sb2 = [0,1,7,4,8,3] if (sb3 == 0 and sb2 > 0) else EQ.get(sb2, [sb2])
    eq_sb3 = [0,1,7,4,8,3] if (sb3 == 0 and sb2 > 0) else EQ.get(sb3, [sb3])
    return (sb2 in eq_sa and sb3 in eq_sb) or (sb3 in eq_sa and sb2 in eq_sb)

def es_directo(a, b):
    """¿Es b un quebrado directo (sin suma) de a?"""
    d1a, d2a = a // 10, a % 10
    subs1 = [x for x in EQ.get(d1a, [d1a]) if x != d1a]
    subs2 = [x for x in EQ.get(d2a, [d2a]) if x != d2a]
    candidatos = set()
    # reves
    if d1a != d2a:
        candidatos.add(d2a * 10 + d1a)
    for s in subs1:
        candidatos.add(s * 10 + d2a)
        if s != d2a: candidatos.add(d2a * 10 + s)
    for s in subs2:
        candidatos.add(d1a * 10 + s)
        if d1a != s: candidatos.add(s * 10 + d1a)
    for s1 in subs1:
        for s2 in subs2:
            candidatos.add(s1 * 10 + s2)
            if s1 != s2: candidatos.add(s2 * 10 + s1)
    return b in candidatos

def relacionados(a, b):
    return es_quebrado(a, b) or es_directo(a, b)

sep = "=" * 65

# ══════════════════════════════════════════════════════════════
print(sep)
print("  ANÁLISIS DE PATRONES - LOTERÍA HONDURAS 2026")
print(sep)

# ── 1. CADENAS DE QUEBRADOS ─────────────────────────────────
print("\n【1】CADENAS DE QUEBRADOS CONSECUTIVOS (2026)\n")

cadenas = []
i = 0
while i < len(draws_2026):
    chain = [draws_2026[i]]
    j = i + 1
    while j < len(draws_2026) and relacionados(chain[-1][2], draws_2026[j][2]):
        chain.append(draws_2026[j])
        j += 1
    if len(chain) >= 3:
        cadenas.append(chain)
        i = j
    else:
        i += 1

print(f"  Cadenas de 3+ sorteos encontradas: {len(cadenas)}\n")
for c in sorted(cadenas, key=lambda x: -len(x)):
    print(f"  Largo {len(c)}:")
    for f, t, n in c:
        print(f"    {f.strftime('%d/%m')} {t:8s}  {n:02d} ({sig(n)})")
    print()

# ── 2. PARES SEMÁNTICOS MISMO DÍA ──────────────────────────
print(sep)
print("\n【2】MISMO GRUPO SEMÁNTICO EN EL MISMO DÍA (2026)\n")

hits_semanticos = []
for f in fechas_2026:
    s = sorteos[f]
    nums = [v for v in [s['maniana'], s['tarde'], s['noche']] if v is not None]
    grupos_dia = [(n, grupo_de(n)) for n in nums if grupo_de(n)]
    vistos = defaultdict(list)
    for n, g in grupos_dia:
        vistos[g].append(n)
    for g, ns in vistos.items():
        if len(ns) >= 2:
            hits_semanticos.append((f, g, ns))
            print(f"  {f.strftime('%d/%m/%Y')}  [{g}]  " +
                  " + ".join(f"{n:02d}({sig(n)})" for n in ns))

print(f"\n  Total días con cluster semántico: {len(hits_semanticos)}")
total_dias_2026 = len(fechas_2026)
print(f"  Sobre {total_dias_2026} días = {len(hits_semanticos)/total_dias_2026*100:.1f}% de los días")

# ── 3. PARES REVERSOS EN ≤3 DÍAS ───────────────────────────
print(f"\n{sep}")
print("\n【3】PARES REVERSOS (n ↔ revés) DENTRO DE 3 DÍAS (2026)\n")

rev_hits = []
nums_2026 = [(f, t, n) for f, t, n in draws_2026]
for i, (f1, t1, n1) in enumerate(nums_2026):
    rev = (n1 % 10) * 10 + (n1 // 10)
    if rev == n1:
        continue  # palíndromo
    for j in range(i+1, min(i+10, len(nums_2026))):
        f2, t2, n2 = nums_2026[j]
        if (f2 - f1).days > 3:
            break
        if n2 == rev:
            rev_hits.append((f1, t1, n1, f2, t2, n2))

print(f"  Pares reversos encontrados: {len(rev_hits)}\n")
for f1, t1, n1, f2, t2, n2 in rev_hits[:30]:
    dias = (f2 - f1).days
    print(f"  {f1.strftime('%d/%m')} {t1:8s} {n1:02d}({sig(n1)})  →  "
          f"{f2.strftime('%d/%m')} {t2:8s} {n2:02d}({sig(n2)})  [{'+' if dias else 'mismo día'}{'' if not dias else str(dias)+'d'}]")

# Expectativa aleatoria
total_draws_2026 = len(draws_2026)
p_rev_random = (1/99) * 9  # prob de que en los 9 sorteos siguientes caiga el reverso
esperado = total_draws_2026 * p_rev_random
print(f"\n  Observado: {len(rev_hits)}  |  Esperado aleatorio: {esperado:.1f}")
print(f"  Ratio: {len(rev_hits)/esperado:.2f}x el azar")

# ── 4. FRECUENCIAS ANÓMALAS 2026 ───────────────────────────
print(f"\n{sep}")
print("\n【4】FRECUENCIAS ANÓMALAS EN 2026\n")

freq_2026 = defaultdict(int)
for _, _, n in draws_2026:
    freq_2026[n] += 1

esperado_por_num = total_draws_2026 / 100
print(f"  Total sorteos 2026: {total_draws_2026}  |  Esperado por número: {esperado_por_num:.1f}\n")

muy_frecuentes = sorted([(n, c) for n, c in freq_2026.items() if c >= esperado_por_num * 1.8],
                         key=lambda x: -x[1])
print("  Números con >1.8x la frecuencia esperada:")
for n, c in muy_frecuentes:
    print(f"    {n:02d} ({sig(n):15s})  {c} veces  ({c/esperado_por_num:.1f}x)")

nunca_2026 = [n for n in range(100) if freq_2026[n] == 0]
print(f"\n  Números que NO han salido en 2026 ({len(nunca_2026)}):")
print("   ", ", ".join(f"{n:02d}({sig(n)})" for n in sorted(nunca_2026)))

# ── 5. MISMO NÚMERO DOS VECES EN EL DÍA ───────────────────
print(f"\n{sep}")
print("\n【5】MISMO NÚMERO DOS VECES EN EL MISMO DÍA (2026)\n")

dobles = []
for f in fechas_2026:
    s = sorteos[f]
    nums = [v for v in [s['maniana'], s['tarde'], s['noche']] if v is not None]
    for n in set(nums):
        if nums.count(n) >= 2:
            dobles.append((f, n, nums.count(n)))
            print(f"  {f.strftime('%d/%m/%Y')}  {n:02d} ({sig(n)})  apareció {nums.count(n)}x  "
                  f"→ {[f'{v:02d}' for v in nums]}")

if not dobles:
    print("  Ninguno.")
print(f"\n  Total: {len(dobles)} días con repetición")
prob_doble_azar = (1 - (99/100)*(98/100)) * len(fechas_2026)
print(f"  Esperado por azar: {prob_doble_azar:.1f} días")

# ── 6. PATRÓN POR DÍA DE SEMANA ────────────────────────────
print(f"\n{sep}")
print("\n【6】DISTRIBUCIÓN POR DÍA DE SEMANA (2026)\n")

dias_semana = ['Lunes','Martes','Miércoles','Jueves','Viernes','Sábado','Domingo']
por_dia = defaultdict(list)
for f, t, n in draws_2026:
    por_dia[f.weekday()].append(n)

for d in range(7):
    nums = por_dia[d]
    if not nums:
        continue
    avg = sum(nums) / len(nums)
    # grupos más frecuentes ese día
    grupos_dia = [grupo_de(n) for n in nums if grupo_de(n)]
    top_grupo = max(set(grupos_dia), key=grupos_dia.count) if grupos_dia else '-'
    print(f"  {dias_semana[d]:10s}  n={len(nums):3d}  promedio={avg:.1f}  "
          f"grupo más común: {top_grupo}")

# ── 7. CADENAS SEMÁNTICAS MULTI-DÍA ─────────────────────────
print(f"\n{sep}")
print("\n【7】CADENAS SEMÁNTICAS (mismo grupo en días consecutivos, 2026)\n")

cadenas_sem = []
for i, f in enumerate(fechas_2026[:-1]):
    f2 = fechas_2026[i+1]
    if (f2 - f).days > 1:
        continue
    nums1 = [v for v in [sorteos[f]['maniana'], sorteos[f]['tarde'], sorteos[f]['noche']] if v is not None]
    nums2 = [v for v in [sorteos[f2]['maniana'], sorteos[f2]['tarde'], sorteos[f2]['noche']] if v is not None]
    grupos1 = set(grupo_de(n) for n in nums1 if grupo_de(n))
    grupos2 = set(grupo_de(n) for n in nums2 if grupo_de(n))
    comunes = grupos1 & grupos2
    for g in comunes:
        ns1 = [n for n in nums1 if grupo_de(n) == g]
        ns2 = [n for n in nums2 if grupo_de(n) == g]
        cadenas_sem.append((f, f2, g, ns1, ns2))

print(f"  Pares de días consecutivos con mismo grupo semántico: {len(cadenas_sem)}\n")
for f1, f2, g, ns1, ns2 in sorted(cadenas_sem, key=lambda x: x[2])[:40]:
    print(f"  {f1.strftime('%d/%m')}→{f2.strftime('%d/%m')}  [{g:12s}]  "
          f"{'+'.join(f'{n:02d}({sig(n)})' for n in ns1)} → "
          f"{'+'.join(f'{n:02d}({sig(n)})' for n in ns2)}")

# ── 8. RESUMEN ESTADÍSTICO GLOBAL ─────────────────────────
print(f"\n{sep}")
print("\n【8】RESUMEN — ¿ES ALEATORIO?\n")

total = len(draws_2026)
# % cadenas quebrado
draws_en_cadena = sum(len(c) for c in cadenas)
print(f"  Sorteos en cadena de quebrados:  {draws_en_cadena}/{total} = {draws_en_cadena/total*100:.1f}%")
print(f"  Días con cluster semántico:      {len(hits_semanticos)}/{total_dias_2026} = {len(hits_semanticos)/total_dias_2026*100:.1f}%")
print(f"  Pares reversos observados/esperados: {len(rev_hits):.0f}/{esperado:.1f} = {len(rev_hits)/max(esperado,1):.2f}x")
print(f"  Días con número repetido:        {len(dobles)}/{total_dias_2026} = {len(dobles)/total_dias_2026*100:.1f}%")
print(f"  Pares día-consecutivo semánticos:{len(cadenas_sem)}/{total_dias_2026} = {len(cadenas_sem)/total_dias_2026*100:.1f}%")
print()
