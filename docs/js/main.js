(function () {
  "use strict";
  var cfg = window.EOTS || {};

  /* ---------- i18n: англійський текст береться з розмітки, українські переклади — тут ---------- */
  var UK = {
    skip: "Перейти до змісту",
    nav_about: "Про гру", nav_features: "Можливості", nav_world: "Світ", nav_bestiary: "Вороги", nav_gallery: "Галерея", nav_download: "Завантажити",
    hero_eyebrow: "Темне фентезі-пригода у стилі PS1",
    hero_tag: "Королівство згоріло. Гора пам'ятає.",
    hero_lead: "Вогні Попелястих земель гаснуть один за одним. Десь на Чорній Горі відкрилося Око. Дорогу до нього пам'ятає лише розірваний атлас.",
    btn_play: "▶ Грати / Завантажити", btn_explore: "Дослідити світ", btn_github: "GitHub",
    about_k: "Про гру", about_h: "Попелясте королівство, прокинуте Око",
    about_p1: "Embers of the Spire — екшн-пригода від третьої особи в незграбному, «хиткому» стилі епохи PlayStation: низькополігональні руїни, тремтіння вершин, дизерінг і смолоскип, якого ніколи не вистачає.",
    about_p2: "Ти прокидаєшся в Селі Попелу, де вмирають придорожні ліхтарі. Орден Печатки колись приспав Око, а потім розірвав єдину карту до його вівтаря на вісім шматків і роздав хранителям. Тепер ті хранителі мертві, божевільні або гірше.",
    about_p3: "Твоя мета — зібрати шматки атласу, зв'язати три уламки Стародавньої Печатки й зійти на Чорну Гору до Ока. Дороги під наглядом, руїни живі, а ніч довга.",
    f1_b: "Жанр", f1_s: "Темний фентезі екшн-пригода", f2_b: "Вигляд", f2_s: "Ретро 3D у стилі PS1 / PSX", f3_b: "Рушій", f4_b: "Платформа", f4_s: "Windows (preview-збірка)",
    f5_b: "Звук", f5_s: "Музика й звуки синтезовані кодом", f6_b: "Стан", f6_s: "Граничний preview, у розробці",
    feat_k: "Що можна робити", feat_h: "Усе навколо небезпеки й відкриттів",
    c1_h: "Великий похмурий світ", c1_p: "Села, мости, озерна фортеця, зруйновані абатства й гірська стежка зі зміною дня та ночі, туманом і погодою. Заходь у хатини, грійся біля печі, гладь кота.",
    c2_h: "Вагомий бій", c2_p: "Меч, щит із вчасним парируванням, лук, витривалість і покращення обладунку. Читай замахи, ухиляйся від важких ударів, обирай момент.",
    c3_h: "Дивні вороги, справжні боси", c3_p: "Скелетна відьма, що піднімає мерців із землі, кістяні лицарі, віщуни, що блимають, Давній Маг, який змінює тактику, і сам Страж Ока.",
    c4_h: "Старі руїни й випробування", c4_p: "Втримай браму від хвиль, збуди рунічні стовпи на час, розбий темні обеліски, витримай Кістяну Яму, піди за білою ланню, знайди мандрівника в тумані.",
    c5_h: "Історія з вагою", c5_p: "Головний сюжет із 13 кроків і трьома мінібосами, багато побічних доручень, масові битви з власним важким саундтреком і фінал, де темрява змінюється світанком.",
    c6_h: "Розірваний атлас", c6_p: "Карта починається шматками. Фрагменти охороняють боси та випробування, а ти дивишся, як кожен шматок повертається на місце, поки не відкриється Чорна Гора.",
    c7_h: "Коні й відкрита дорога", c7_p: "Купи коня в конярі, їдь кроком, риссю чи галопом (галоп втомлює), перемикайся на вигляд від першої особи в сідлі й топчи тих, хто влаштував засідку.",
    c8_h: "Атмосфера PS1 dark fantasy", c8_p: "Піксельний рендер, дизерінг, хиткі вершини, попіл і світло смолоскипа. Раптові події в дорозі: ворони, дивні голоси, високі силуети вдалині.",
    world_cap: "Атлас Забутих Земель у грі", world_k: "Світ і його історія", world_h: "Попелясті землі",
    world_p1: "Корона старого королівства впала, а попіл і досі кружляє над дорогами. Над руїнами піднялася Чорна Гора, а на її вершині — Око, яке королівство колись приспало Печаттю з трьох уламків.",
    world_p2: "Орден Печатки боявся, що хтось знову його розбудить, тож монахи розірвали атлас із дорогою до вівтаря й віддали шматки тим людям і лицарям, яким довіряли найбільше. Тепер вогні вздовж дороги гаснуть, хранителі змінилися, а Око дивиться у відповідь.",
    t1: "Село Попелу", t2: "Забуте кладовище", t3: "Руїни Абатства", t4: "Попеляста цитадель", t5: "Фортеця Чорного Прапора", t6: "Німі Камені", t7: "Чорна Гора",
    bs_k: "Особливі вороги", bs_h: "Не всі мерці лежать спокійно",
    b1_h: "Кістяна Вдова", b1_p: "Скелетна відьма, що тримає дистанцію, попереджає піднятими руками й виводить скелетів із тріснутої землі. Зірви її ритуал або вбий першою.",
    b2_h: "Кістяні шакали", b2_p: "Швидкі скелети-воїни: кружляють зграєю й кидаються з усіх боків.",
    b3_h: "Кістяний вартовий", b3_p: "Повільний броньований лицар-мрець. Звичайні удари його не збивають, а його удари з червоним колом карають тих, хто стоїть на місці. Парируй.",
    b4_h: "Попелястий віщун", b4_p: "Заклиначник: стріляє здалеку й блимає геть, щойно підійти.",
    b5_h: "Давній Маг", b5_p: "Міні-бос Крижаної вежі. Сипле віяла крижаних куль, ховається за сферами-щитами, які треба розбити, а далі сипле крижані шипи.",
    b6_h: "Страж Ока", b6_p: "Фінальний бос: три фази, телепорти з попереджувальними колами, ударні хвилі й вогонь. Переможи його — і вирви Око з вівтаря.",
    gal_k: "Галерея", gal_h: "Скріншоти з гри", gal_n: "Усі зображення — справжні кадри з гри (інтерфейс поки що українською).",
    dl_k: "Завантаження", dl_sub: "Windows-збірка — граничний preview",
    dl_p: "Один самодостатній виконуваний файл: без інсталятора й зайвих файлів. Ранні версії сирі: можливі помилки й зміни балансу.",
    dl_btn: "Завантажити для Windows",
    dl_note: "Посилання на завантаження з'явиться тут, щойно буде опубліковано перший GitHub Release.",
    how_h: "Як запустити",
    how1: "Завантаж <code>EmbersOfTheSpire.exe</code> зі сторінки Release.",
    how2: "Поклади його в будь-яку теку й двічі клікни. Якщо Windows SmartScreen попередить про непідписаний застосунок — «Докладніше → Усе одно виконати».",
    how3: "Під час першого запуску будується рельєф і кешується; наступні запуски швидші.",
    req_h: "Системні вимоги",
    req_p: "Windows 10/11, 64-біт, відеокарта з підтримкою Vulkan (гра використовує рендерер Godot Forward+). Точні мінімальні вимоги ще не виміряні. Розмір exe — близько 120 МБ.",
    ctl_h: "Керування", ctl_p: "Рух · біг · стрибок · удар · щит/парирування · дія · вигляд · лук · журнал · карта · сумка · свисток для коня.",
    dev_k: "Розробка", dev_h: "Зроблено кодом",
    dev_p1: "Embers of the Spire — незалежний проєкт на GDScript і Godot 4.7. Майже все процедурне: ландшафт, будівлі, текстури, персонажі й обличчя збираються з коду, а кожен звук і музичний трек синтезуються офлайн інструментами самої гри.",
    dev_p2: "Проєкт розвивається покроково; зараз акцент на контенті, різноманітності бою та доведенні.",
    rm_k: "Дорожня карта", rm_h: "Що далі", rm_note: "Плани, а не обіцянки: цього ще немає в грі.",
    rm1: "Баланс, виправлення помилок і оптимізація", rm2: "Більше випробувань, мінібосів і підземель", rm3: "Англійський інтерфейс і субтитри в грі", rm4: "Підтримка геймпада й більше налаштувань", rm5: "Слоти збереження",
    cr_k: "Подяки", cr_h: "Подяки",
    cr_p1: "Дизайн, код, процедурна графіка та звук — автор Embers of the Spire. Створено на рушії Godot (ліцензія MIT).",
    cr_p2: "Герой, вороги, світ, музика й звуки створюються кодом самої гри; сторонніх моделей, анімацій чи аудіо немає.",
    li_k: "Ліцензія і контакти", li_h: "Ліцензія",
    li_p: "Вихідний код і власний процедурний контент проєкту — під ліцензією MIT. Подробиці в репозиторії.",
    foot: "Зроблено на Godot. Без трекерів і cookie.", totop: "Нагору ↑",
    g1: "Місяць над Чорною Горою", g2: "Чорна Гора вночі", g3: "Село Попелу", g4: "Попеляста цитадель", g5: "Вежа з Оком на заході сонця", g6: "Світанок після падіння Ока",
    g7: "Фортеця Чорного Прапора на озері", g8: "Дерев'яний міст над темною водою", g9: "Вівтар Ока", g10: "Вирвати Око", g11: "Змієва подоба Ока",
    g12: "Масова битва вночі", g13: "Випробування Кістяна Яма", g14: "Хатина мисливця", g15: "Сумка", g16: "Карти з магом", g17: "Руїни під місяцем"
  };
  var EN = {};
  var captionsEn = ["Moonrise over the Black Mountain", "The Black Mountain by night", "The Village of Ash", "The Ashen Citadel", "The Eye altar tower at dusk", "Dawn after the Eye falls",
    "Black Banner Fortress on the lake", "A wooden bridge over dark water", "The Altar of the Eye", "Tearing out the Eye", "The Eye's serpent form",
    "A mass battle at night", "The Bone Pit trial", "A hunter's hut", "Inventory", "A card game with the mage", "Ruins under the moon"];
  captionsEn.forEach(function (c, i) { EN["g" + (i + 1)] = c; });

  var nodes = document.querySelectorAll("[data-i18n]");
  nodes.forEach(function (n) { EN[n.getAttribute("data-i18n")] = n.innerHTML; });
  var lang = "en";

  function t(key) { var d = lang === "uk" ? UK : EN; return d[key] !== undefined ? d[key] : (EN[key] || ""); }

  function applyLang(l, save) {
    lang = l;
    document.documentElement.lang = l === "uk" ? "uk" : "en";
    nodes.forEach(function (n) {
      var k = n.getAttribute("data-i18n");
      if (UK[k] !== undefined || EN[k] !== undefined) n.innerHTML = t(k);
    });
    document.querySelectorAll(".lang button").forEach(function (b) { b.setAttribute("aria-pressed", String(b.dataset.lang === l)); });
    document.title = l === "uk" ? "Embers of the Spire — темна фентезі-пригода у стилі PS1" : "Embers of the Spire — PS1 Dark Fantasy Action Adventure";
    var d = document.querySelector('meta[name="description"]');
    if (d) d.setAttribute("content", l === "uk" ? "Embers of the Spire — темна фентезі-пригода у стилі PS1 на Godot: зруйноване королівство, розірваний атлас і прокинуте Око на Чорній Горі." : "Embers of the Spire is a PS1-inspired dark fantasy action adventure built with Godot: a ruined kingdom, a torn atlas, an awakened Eye on the Black Mountain.");
    document.querySelectorAll(".shot").forEach(function (s) { s.setAttribute("aria-label", t(s.dataset.cap)); });
    applyLinks();
    if (save) { try { localStorage.setItem("eots-lang", l); } catch (e) {} }
  }

  document.querySelectorAll(".lang button").forEach(function (b) {
    b.addEventListener("click", function () { applyLang(b.dataset.lang, true); });
  });

  var saved = null;
  try { saved = localStorage.getItem("eots-lang"); } catch (e) {}
  var pref = saved || ((navigator.language || "").toLowerCase().indexOf("uk") === 0 ? "uk" : "en");

  /* ---------- Посилання: порожні = вимкнені (ніяких фальшивих URL) ---------- */
  function applyLinks() {
    document.querySelectorAll("[data-link]").forEach(function (a) {
      var url = cfg[a.getAttribute("data-link")];
      if (url) {
        a.href = url; a.removeAttribute("aria-disabled"); a.removeAttribute("tabindex");
        if (a.getAttribute("data-link") === "repo") { a.target = "_blank"; a.rel = "noopener"; }
      } else {
        a.removeAttribute("href"); a.setAttribute("aria-disabled", "true"); a.setAttribute("tabindex", "-1");
      }
    });
    var note = document.getElementById("dl-note");
    if (note) note.style.display = cfg.release ? "none" : "";
  }

  /* ---------- Меню ---------- */
  var nav = document.querySelector(".nav"), burger = document.getElementById("burger"), links = document.getElementById("links");
  burger.addEventListener("click", function () {
    var o = links.classList.toggle("open");
    burger.setAttribute("aria-expanded", String(o));
  });
  links.addEventListener("click", function (e) { if (e.target.tagName === "A") { links.classList.remove("open"); burger.setAttribute("aria-expanded", "false"); } });
  function onScroll() { nav.classList.toggle("solid", window.scrollY > 40); }
  window.addEventListener("scroll", onScroll, { passive: true }); onScroll();

  /* ---------- Поява блоків ---------- */
  var rev = document.querySelectorAll(".reveal");
  if ("IntersectionObserver" in window) {
    var io = new IntersectionObserver(function (es) {
      es.forEach(function (e) { if (e.isIntersecting) { e.target.classList.add("in"); io.unobserve(e.target); } });
    }, { threshold: 0.12 });
    rev.forEach(function (r) { io.observe(r); });
  } else { rev.forEach(function (r) { r.classList.add("in"); }); }

  /* ---------- Галерея / лайтбокс ---------- */
  var shots = Array.prototype.slice.call(document.querySelectorAll(".shot"));
  var lb = document.getElementById("lb"), lbImg = document.getElementById("lb-img"), lbCap = document.getElementById("lb-cap");
  var cur = 0, opener = null;
  function show(i) {
    cur = (i + shots.length) % shots.length;
    var s = shots[cur], img = s.querySelector("img");
    lbImg.src = img.getAttribute("src"); lbImg.alt = img.alt; lbCap.textContent = t(s.dataset.cap);
  }
  function open(i) { opener = document.activeElement; show(i); lb.hidden = false; document.body.style.overflow = "hidden"; document.getElementById("lb-x").focus(); }
  function close() { lb.hidden = true; document.body.style.overflow = ""; if (opener) opener.focus(); }
  shots.forEach(function (s, i) { s.addEventListener("click", function () { open(i); }); });
  document.getElementById("lb-x").addEventListener("click", close);
  document.getElementById("lb-p").addEventListener("click", function () { show(cur - 1); });
  document.getElementById("lb-nx").addEventListener("click", function () { show(cur + 1); });
  lb.addEventListener("click", function (e) { if (e.target === lb) close(); });
  document.addEventListener("keydown", function (e) {
    if (lb.hidden) return;
    if (e.key === "Escape") close();
    else if (e.key === "ArrowLeft") show(cur - 1);
    else if (e.key === "ArrowRight") show(cur + 1);
  });

  /* ---------- Попіл (легкий canvas) ---------- */
  var cv = document.getElementById("ash"), ctx = cv.getContext("2d");
  var reduce = window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  if (!reduce && ctx) {
    var W, H, parts = [], N = window.innerWidth < 700 ? 28 : 60;
    function size() { W = cv.width = window.innerWidth; H = cv.height = window.innerHeight; }
    size(); window.addEventListener("resize", size);
    for (var i = 0; i < N; i++) parts.push({ x: Math.random() * 2000, y: Math.random() * 1200, r: Math.random() * 1.8 + .6, v: Math.random() * .5 + .25, d: Math.random() * 1.2 - .3, e: Math.random() < .25 });
    (function frame() {
      if (!document.hidden) {
        ctx.clearRect(0, 0, W, H);
        parts.forEach(function (p) {
          p.y -= p.v * (p.e ? 1.3 : .6); p.x += p.d + Math.sin(p.y * .01) * .3;
          if (p.y < -10 || p.x > W + 10 || p.x < -10) { p.y = H + 10; p.x = Math.random() * W; }
          ctx.fillStyle = p.e ? "rgba(255,150,50,.85)" : "rgba(190,175,155,.55)";
          ctx.fillRect(Math.round(p.x), Math.round(p.y), Math.ceil(p.r), Math.ceil(p.r));
        });
      }
      requestAnimationFrame(frame);
    })();
  }

  applyLang(pref, false);
})();
