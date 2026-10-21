#!/usr/bin/env python3
"""Generate the BoosterFish 30-day social editorial package."""

from __future__ import annotations

import csv
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CONTENT = ROOT / "content"


POSTS = [
    {
        "day": 1, "slug": "manifesto", "series": "CAP SUR BOOSTERFISH", "language": "FR + Darija",
        "objective": "Notoriété", "background": "atlantic_shore.png",
        "screens": ["Et si chaque sortie commençait mieux ?", "Spots, mer, marées et techniques", "Tout préparer dans une seule app", "BoosterFish — bientôt disponible"],
        "voiceover": "Et si chaque sortie en mer commençait avec les bonnes informations ? BoosterFish réunit la préparation essentielle dans une seule application. قريباً، الصيد غادي يولي منظم أكثر.",
        "caption": "Une sortie réussie commence bien avant le premier lancer. BoosterFish rassemble carte, conditions marines, marées, espèces et techniques dans une expérience pensée pour les pêcheurs en mer. التطبيق مازال فالتست المغلق، وقريباً نشاركو معاكم الجديد. 🎣🌊",
        "cta": "Suivez la page pour le lancement", "hashtags": "#BoosterFish #PecheEnMer #Maroc #FishingApp #صيد_البحر"
    },
    {
        "day": 2, "slug": "checklist_depart", "series": "AVANT DE PARTIR", "language": "FR",
        "objective": "Utilité", "background": "home_hero.png",
        "screens": ["Avant de partir : 4 vérifications", "Vent • vagues • marées", "Accès au spot • matériel", "Préparez. Vérifiez. Pêchez."],
        "voiceover": "Avant de partir, vérifiez le vent, les vagues, les marées et l'accès au spot. Une minute de préparation peut changer toute la sortie.",
        "caption": "Votre checklist express avant une sortie : conditions marines, marées, accès au spot et matériel adapté. BoosterFish aide à regrouper ces informations sans promettre la prise : la décision finale reste toujours celle du pêcheur.",
        "cta": "Enregistrez cette checklist", "hashtags": "#ConseilPeche #PecheEnMer #BoosterFish #SortiePeche"
    },
    {
        "day": 3, "slug": "safety_darija", "series": "البحر أولاً", "language": "Darija",
        "objective": "Sécurité", "background": "atlantic_shore.png",
        "screens": ["قبل ما تخرج للبحر", "شوف الريح والموج", "وتأكد من حالة المد والجزر", "السلامة ديالك هي الأولى"],
        "voiceover": "قبل ما تخرج تصيد، شوف الريح والموج والمد والجزر. البحر ما كيتغامرش معاه، والسلامة ديالك هي الأولى.",
        "caption": "قبل أي خرجة: راقب الريح، الموج، والمد والجزر، وخبر شي واحد فين غادي. BoosterFish كيساعدك تحضر، والقرار الآمن كيبقى ديالك. 🌊",
        "cta": "صيفطها لصاحبك", "hashtags": "#BoosterFish #صيد_البحر #المغرب #السلامة_أولاً"
    },
    {
        "day": 4, "slug": "official_spots", "series": "CARTE MARINE", "language": "FR",
        "objective": "Fonctionnalité", "background": "home_hero.png",
        "screens": ["Plus de 6 000 spots officiels", "Repérez la zone qui vous intéresse", "Consultez avant de vous déplacer", "La carte BoosterFish"],
        "voiceover": "BoosterFish intègre plus de six mille spots officiels. Explorez la carte et préparez votre zone avant de vous déplacer.",
        "caption": "Explorez plus de 6 000 spots officiels dans BoosterFish. La carte sert à préparer votre recherche ; elle ne remplace ni la réglementation locale, ni la vérification de l'accès, ni votre jugement sur place.",
        "cta": "Quel littoral voulez-vous explorer ?", "hashtags": "#CarteDePeche #BoosterFish #PecheMaroc #FishingSpots"
    },
    {
        "day": 5, "slug": "private_spots", "series": "VOS SPOTS", "language": "Darija",
        "objective": "Confiance", "background": "atlantic_shore.png",
        "screens": ["السبوط ديالك… يبقى ديالك", "سجّل المكان فحسابك", "الإحداثيات كتبقى مخفية", "نظّم سبوطاتك الخاصة"],
        "voiceover": "لقيتي سبوط مزيان؟ سجلو فحسابك. السبوط الخاص والإحداثيات ديالو كيبقاو مخفيين.",
        "caption": "السبوطات الخاصة ديالك كتبقى فحسابك، والإحداثيات ديالها مخفية. نظم الأماكن اللي بغيتي ترجع ليها بلا ما تنشر الموقع للعموم.",
        "cta": "شنو أهم حاجة فسبوط مزيان؟", "hashtags": "#BoosterFish #سبوطات_الصيد #صيد_البحر #خصوصية"
    },
    {
        "day": 6, "slug": "read_tides", "series": "1 MINUTE MARÉES", "language": "FR",
        "objective": "Éducation", "background": "tides.png",
        "screens": ["Marée haute ou marée basse ?", "Regardez surtout l'évolution", "Horaire + hauteur + tendance", "Planifiez votre créneau"],
        "voiceover": "Une marée ne se résume pas à haute ou basse. Regardez l'horaire, la hauteur et la phase de montée ou de descente pour préparer votre créneau.",
        "caption": "Pour lire une marée, observez trois éléments : l'heure, la hauteur et l'évolution. Les conditions locales peuvent modifier la situation réelle ; vérifiez toujours le terrain.",
        "cta": "Gardez ce rappel pour votre prochaine sortie", "hashtags": "#Marees #PecheEnMer #BoosterFish #ConseilPeche"
    },
    {
        "day": 7, "slug": "fg_knot", "series": "NŒUD DU JOUR", "language": "FR",
        "objective": "Éducation", "background": "knot_fg.png",
        "screens": ["Tresse vers fluorocarbone", "Découvrez le nœud FG", "Suivez chaque étape dans l'app", "Serrez et testez avant usage"],
        "voiceover": "Pour relier une tresse à un bas de ligne, découvrez le nœud FG dans BoosterFish. Suivez les étapes, serrez progressivement et testez toujours votre montage.",
        "caption": "Le nœud FG est une option courante pour relier tresse et bas de ligne. Le tutoriel BoosterFish détaille le geste. Adaptez toujours le nœud au diamètre, au fil et à l'usage.",
        "cta": "Enregistrez le tutoriel", "hashtags": "#NoeudFG #Jigging #BoosterFish #MontagePeche"
    },
    {
        "day": 8, "slug": "palomar_knot", "series": "عقدة اليوم", "language": "Darija",
        "objective": "Éducation", "background": "knot_palomar.png",
        "screens": ["عقدة Palomar", "بسيطة وواضحة", "تبع المراحل وحدة بوحدة", "وجرّب القوة قبل الصيد"],
        "voiceover": "عقدة بالومار بسيطة فالتعلم. تبع المراحل وحدة بوحدة، شدها مزيان، وجرّبها قبل ما تبدا الصيد.",
        "caption": "عقدة Palomar كتستعمل فبزاف ديال التركيبات. تعلمها بالصور داخل BoosterFish، وديما بلّل الخيط وشد بالتدريج حسب نوع الخيط.",
        "cta": "حفظ الفيديو وجربها", "hashtags": "#BoosterFish #عقد_الصيد #Palomar #صيد_البحر"
    },
    {
        "day": 9, "slug": "clinch_knot", "series": "NŒUD DU JOUR", "language": "FR",
        "objective": "Éducation", "background": "knot_improved-clinch.png",
        "screens": ["Attacher un hameçon ou émerillon", "Nœud Clinch amélioré", "Des étapes visuelles claires", "Toujours contrôler le serrage"],
        "voiceover": "Le Clinch amélioré est un classique pour certains montages. Apprenez sa séquence dans BoosterFish et contrôlez toujours le serrage avant de lancer.",
        "caption": "Un bon nœud dépend aussi du fil, du diamètre et du montage. Le guide montre le Clinch amélioré étape par étape, avec un rappel simple : testez chaque nœud avant usage.",
        "cta": "Quel nœud utilisez-vous le plus ?", "hashtags": "#NoeudDePeche #Clinch #BoosterFish #TechniquePeche"
    },
    {
        "day": 10, "slug": "offshore_swivel", "series": "BIG GAME", "language": "FR + Darija",
        "objective": "Éducation", "background": "knot_offshore-swivel.png",
        "screens": ["Montages puissants en mer", "Connexion vers émerillon", "Suivez le guide Offshore", "قوّي التركيب واختبرو"],
        "voiceover": "Pour les montages offshore, la connexion vers l'émerillon demande de la rigueur. تبع المراحل واختبر التركيب قبل الاستعمال.",
        "caption": "Les montages destinés à des poissons puissants exigent un matériel dimensionné et un nœud parfaitement exécuté. Le guide Offshore Swivel de BoosterFish sert de support visuel ; choisissez toujours fil, émerillon et frein selon votre pratique.",
        "cta": "Partagez à votre équipage", "hashtags": "#BigGameFishing #Traîne #BoosterFish #صيد_الكبار"
    },
    {
        "day": 11, "slug": "jigging_prep", "series": "PRÉPARATION JIGGING", "language": "FR",
        "objective": "Technique", "background": "offshore_jigging.png",
        "screens": ["Avant une session jigging", "Contrôlez ligne et bas de ligne", "Vérifiez anneaux, agrafes et hameçons", "Préparez avant d'embarquer"],
        "voiceover": "Avant une session jigging, contrôlez la ligne, le bas de ligne, les anneaux, les agrafes et les hameçons. Faites ces vérifications à quai.",
        "caption": "Checklist jigging : état de la tresse, bas de ligne, connexion, anneaux brisés, hameçons et frein. Une vérification simple évite une mauvaise surprise au large.",
        "cta": "Enregistrez la checklist", "hashtags": "#Jigging #PecheAuLarge #BoosterFish #FishingTips"
    },
    {
        "day": 12, "slug": "trolling_prep", "series": "PRÉPARATION TRAÎNE", "language": "Darija",
        "objective": "Technique", "background": "offshore_jigging.png",
        "screens": ["قبل التراينة", "راجع الخيط والليدر", "تأكد من الفرامل والسلامة", "وجد كلشي قبل الانطلاق"],
        "voiceover": "قبل التراينة، راجع الخيط والليدر والعقد، وتأكد من الفرامل وتجهيزات السلامة. وجد كلشي قبل ما يخرج القارب.",
        "caption": "فالتراينة، التنظيم مهم: راجع الخيط، الليدر، العقد، الفرامل، والطُعم. وتجهيزات السلامة خاصها تكون واجدة قبل الخروج.",
        "cta": "شاركها مع طاقم القارب", "hashtags": "#BoosterFish #التراينة #صيد_البحر #Trolling"
    },
    {
        "day": 13, "slug": "species_guide", "series": "CONNAÎTRE L'ESPÈCE", "language": "FR",
        "objective": "Découverte", "background": "species.png",
        "screens": ["Vous avez identifié l'espèce ?", "Consultez sa fiche", "Habitat • conseils • périodes", "Mieux connaître avant de pêcher"],
        "voiceover": "Avant de cibler une espèce, apprenez à la reconnaître et consultez les informations disponibles dans sa fiche BoosterFish.",
        "caption": "Les fiches espèces de BoosterFish rassemblent des informations utiles pour mieux comprendre les poissons marins. Pour les tailles, quotas et périodes autorisées, référez-vous toujours aux règles locales en vigueur.",
        "cta": "Quelle espèce voulez-vous voir ?", "hashtags": "#PoissonsMarins #BoosterFish #PecheResponsable #Ocean"
    },
    {
        "day": 14, "slug": "sea_conditions", "series": "LIRE LA MER", "language": "FR + Darija",
        "objective": "Sécurité", "background": "tides.png",
        "screens": ["Vent faible ≠ mer toujours calme", "Regardez aussi les vagues", "Direction, période et évolution", "شوف الصورة كاملة"],
        "voiceover": "Un vent faible ne garantit pas une mer calme. Regardez aussi les vagues et leur évolution. شوف المعطيات كاملة قبل القرار.",
        "caption": "Ne prenez pas une décision sur un seul indicateur. Vent, vagues, marées et terrain doivent être lus ensemble. BoosterFish aide à consulter les données ; votre sécurité exige aussi l'observation réelle sur place.",
        "cta": "Envoyez ce rappel à votre binôme", "hashtags": "#MeteoMarine #SecuriteEnMer #BoosterFish #السلامة"
    },
    {
        "day": 15, "slug": "offline_maps", "series": "MODE HORS LIGNE", "language": "FR",
        "objective": "Résilience", "background": "atlantic_shore.png",
        "screens": ["Le réseau peut disparaître en mer", "Téléchargez la carte avant", "Activez votre région hors ligne", "Préparez-la tant que vous avez du réseau"],
        "voiceover": "En mer, le réseau peut devenir instable. Téléchargez et activez votre carte hors ligne avant de partir, tant que la connexion est disponible.",
        "caption": "Conseil pratique : préparez la région hors ligne avant la sortie. Une carte déjà téléchargée reste utile quand le réseau devient faible. Vérifiez le téléchargement et l'espace disponible avant de partir.",
        "cta": "Ajoutez cette étape à votre routine", "hashtags": "#HorsLigne #CarteMarine #BoosterFish #PecheEnMer"
    },
    {
        "day": 16, "slug": "community_privacy", "series": "COMMUNAUTÉ", "language": "Darija",
        "objective": "Confiance", "background": "community.png",
        "screens": ["شارك الصيدة… ماشي السبوط", "الموقع العمومي تقريبي", "السبوط الخاص كيبقى مخفي", "شارك بمسؤولية"],
        "voiceover": "فالمجتمع ديال BoosterFish تقدر تشارك الصيدة، والموقع العمومي كيبان تقريبي. السبوط الخاص ديالك كيبقى مخفي.",
        "caption": "شارك التجربة والصيدة بمسؤولية. فالنشر العمومي، الموقع كيبقى تقريبي، أما السبوطات الخاصة والإحداثيات ديالها فكتبقى مخفية فحسابك.",
        "cta": "شنو بغيتي تشوف فمجتمع الصيادة؟", "hashtags": "#BoosterFish #مجتمع_الصيادة #صيد_البحر #خصوصية"
    },
    {
        "day": 17, "slug": "publish_catch", "series": "VOTRE PRISE", "language": "FR",
        "objective": "Engagement", "background": "community.png",
        "screens": ["Une prise, une histoire", "Ajoutez votre photo", "Partagez l'expérience avec la communauté", "Votre spot privé reste protégé"],
        "voiceover": "Une prise raconte une histoire. Publiez votre photo et partagez votre expérience avec la communauté sans révéler votre spot privé.",
        "caption": "Photo, espèce, récit : partagez ce qui rend votre sortie mémorable. BoosterFish sépare la publication communautaire de vos spots personnels privés.",
        "cta": "Préparez votre première publication", "hashtags": "#PriseDuJour #BoosterFish #CommunautePeche #FishingLife"
    },
    {
        "day": 18, "slug": "community_controls", "series": "COMMUNAUTÉ SÛRE", "language": "FR",
        "objective": "Confiance", "background": "community.png",
        "screens": ["Une communauté demande des règles", "Signaler un contenu", "Bloquer un compte", "Garder un espace respectueux"],
        "voiceover": "BoosterFish prévoit des outils pour signaler un contenu et bloquer un compte. Chaque membre contribue à garder un espace respectueux.",
        "caption": "Une communauté utile doit aussi être modérée. Les fonctions de signalement et de blocage permettent d'agir face à un contenu ou un comportement inadapté.",
        "cta": "Respectez la mer et la communauté", "hashtags": "#CommunauteResponsable #BoosterFish #Pecheurs #Respect"
    },
    {
        "day": 19, "slug": "fishing_shops", "series": "PRÈS DE VOUS", "language": "FR + Darija",
        "objective": "Fonctionnalité", "background": "shops.png",
        "screens": ["Un article manque avant la sortie ?", "Repérez des magasins de pêche", "Préparez votre trajet", "لقى التجهيزات القريبة"],
        "voiceover": "Un article manque avant la sortie ? Repérez des magasins de pêche dans BoosterFish et préparez votre trajet. لقى المحلات القريبة منك.",
        "caption": "Besoin de compléter le matériel ? La section magasins aide à repérer des commerces d'articles de pêche. Vérifiez les horaires et la disponibilité directement auprès du magasin.",
        "cta": "Quel magasin recommandez-vous ?", "hashtags": "#MagasinDePeche #BoosterFish #MaterielDePeche #المغرب"
    },
    {
        "day": 20, "slug": "personal_log", "series": "MÉMOIRE DE PÊCHE", "language": "FR",
        "objective": "Rétention", "background": "atlantic_shore.png",
        "screens": ["Ne perdez plus le fil de vos sorties", "Enregistrez vos spots personnels", "Ajoutez vos propres repères", "Construisez votre mémoire de pêche"],
        "voiceover": "Enregistrez vos spots personnels et vos repères pour construire votre propre mémoire de pêche, sortie après sortie.",
        "caption": "Votre expérience vaut plus qu'un souvenir flou. Organisez vos spots personnels dans votre compte pour retrouver rapidement les lieux que vous souhaitez revisiter.",
        "cta": "Commencez par votre dernier spot", "hashtags": "#CarnetDePeche #SpotsPrives #BoosterFish #FishingLog"
    },
    {
        "day": 21, "slug": "forecast_honesty", "series": "PÊCHER PLUS LUCIDE", "language": "Darija",
        "objective": "Crédibilité", "background": "tides.png",
        "screens": ["التوقعات ماشي ضمانة", "هي وسيلة باش تحضّر", "قارن المعطيات مع الواقع", "والقرار الأخير ديالك"],
        "voiceover": "التوقعات ماشي ضمانة ديال الصيد. هي وسيلة باش تحضر وتقارن المعطيات مع الحالة الحقيقية فالبحر.",
        "caption": "لا تطبيق يقدر يضمن الصيدة. التوقعات كتعاونك تنظم الوقت وتفهم الظروف، ولكن خاصك ديما تقارنها مع الواقع وتحترم السلامة والقوانين المحلية.",
        "cta": "الصراحة أولاً", "hashtags": "#BoosterFish #توقعات_البحر #صيد_مسؤول #المغرب"
    },
    {
        "day": 22, "slug": "closed_test", "series": "TEST FERMÉ", "language": "FR",
        "objective": "Transparence", "background": "home_hero.png",
        "screens": ["BoosterFish est en test fermé", "De vrais pêcheurs testent l'app", "Chaque retour est analysé", "Objectif : une sortie fiable"],
        "voiceover": "BoosterFish est actuellement en test fermé. Les retours servent à corriger les problèmes et à préparer une version publique plus fiable.",
        "caption": "La version actuelle est distribuée à un groupe de testeurs via Google Play. Nous suivons les retours, les parcours essentiels et la stabilité avant de demander l'accès à la production.",
        "cta": "Testeur invité ? Envoyez votre retour", "hashtags": "#ClosedTesting #BoosterFish #BetaTest #ApplicationMobile"
    },
    {
        "day": 23, "slug": "tester_mission", "series": "MISSION TESTEUR", "language": "FR + Darija",
        "objective": "Collecte de retours", "background": "home_hero.png",
        "screens": ["Testez comme lors d'une vraie sortie", "Démarrage • carte • marées", "Spots privés • communauté • hors ligne", "قول لينا فين كاين المشكل"],
        "voiceover": "Testez l'application comme pendant une vraie sortie : démarrage, carte, marées, spots privés, communauté et mode hors ligne. وأي مشكل، وصفو لينا بوضوح.",
        "caption": "Pour les testeurs invités : indiquez le modèle du téléphone, la version Android, l'écran concerné, les étapes et ce qui s'est passé. Une description précise accélère la correction.",
        "cta": "Envoyez un retour précis", "hashtags": "#Testeurs #BoosterFish #Feedback #اختبار_التطبيق"
    },
    {
        "day": 24, "slug": "plan_darija", "series": "خطط للخرجة", "language": "Darija",
        "objective": "Utilité", "background": "atlantic_shore.png",
        "screens": ["الخرجة كتبدا قبل البحر", "اختار المنطقة", "شوف الظروف وجهز العتاد", "ومن بعد قرر بسلامة"],
        "voiceover": "الخرجة المزيانة كتبدا قبل البحر. اختار المنطقة، شوف الظروف، وجد العتاد، ومن بعد خذ القرار اللي فيه السلامة.",
        "caption": "خطة بسيطة: المنطقة، حالة البحر، المد والجزر، الوصول، والعتاد. BoosterFish كيجمع ليك أدوات التحضير فبلاصة وحدة.",
        "cta": "شنو أول حاجة كتراجع؟", "hashtags": "#BoosterFish #خرجة_الصيد #صيد_البحر #المغرب"
    },
    {
        "day": 25, "slug": "one_app", "series": "UNE APP, UNE SORTIE", "language": "FR",
        "objective": "Positionnement", "background": "home_hero.png",
        "screens": ["Moins d'apps à ouvrir", "Carte et spots", "Mer, marées, espèces, techniques", "BoosterFish centralise la préparation"],
        "voiceover": "Carte, conditions marines, marées, espèces et techniques : BoosterFish centralise les outils essentiels de préparation.",
        "caption": "L'idée BoosterFish est simple : réduire les allers-retours entre plusieurs outils avant une sortie en mer. Les données restent des aides à la décision, à compléter par la réglementation et l'observation locale.",
        "cta": "Quelle fonction vous fait gagner le plus de temps ?", "hashtags": "#BoosterFish #FishingApp #PecheEnMer #Application"
    },
    {
        "day": 26, "slug": "big_game_prep", "series": "THON • MARLIN • ESPADON", "language": "FR",
        "objective": "Technique", "background": "offshore_jigging.png",
        "screens": ["Cibler un poisson puissant ?", "Dimensionnez tout le montage", "Ligne • leader • nœuds • frein", "Aucun maillon ne doit être improvisé"],
        "voiceover": "Pour le thon, le marlin ou l'espadon, chaque élément du montage doit être dimensionné : ligne, leader, nœuds, hameçon et frein.",
        "caption": "La pêche des grands pélagiques demande expérience, matériel adapté, équipage préparé et respect strict des règles locales. BoosterFish apporte des guides techniques, mais ne remplace ni la formation ni l'encadrement professionnel.",
        "cta": "Préparez le montage à quai", "hashtags": "#Thon #Marlin #Espadon #BigGameFishing #BoosterFish"
    },
    {
        "day": 27, "slug": "bimini_yucatan", "series": "CONNEXIONS BIG GAME", "language": "FR + Darija",
        "objective": "Éducation", "background": "knot_studio.png",
        "screenBackgrounds": ["knot_studio.png", "knot_bimini-twist.png", "knot_yucatan.png", "knot_studio.png"],
        "screens": ["Deux nœuds à connaître", "Bimini Twist", "Yucatan", "تعلم، شد، واختبر"],
        "voiceover": "Découvrez le Bimini Twist et le Yucatan dans les guides BoosterFish. تعلم المراحل، شد بالتدريج، واختبر قبل الاستعمال.",
        "caption": "Bimini Twist et Yucatan font partie des connexions utilisées dans certains montages puissants. Le choix dépend du fil, du diamètre et de la configuration. Entraînez-vous à terre avant de les utiliser en mer.",
        "cta": "Lequel voulez-vous apprendre d'abord ?", "hashtags": "#BiminiTwist #YucatanKnot #BigGame #BoosterFish"
    },
    {
        "day": 28, "slug": "knot_quiz", "series": "QUIZ PÊCHE", "language": "Darija",
        "objective": "Engagement", "background": "knot_studio.png",
        "screens": ["سؤال للصيادة", "شنو العقدة اللي كتستعمل", "باش تربط التريس بالليدر؟", "كتب الجواب فالتعليقات"],
        "voiceover": "سؤال اليوم: شنو العقدة اللي كتستعمل باش تربط التريس بالليدر؟ FG، Albright، Yucatan، ولا عقدة أخرى؟",
        "caption": "كل صياد عندو الاختيار ديالو حسب الخيط والتركيب. قول لينا: FG، Albright، Yucatan، ولا شي عقدة أخرى؟ وشنو السبب؟",
        "cta": "جاوب فالتعليقات", "hashtags": "#BoosterFish #سؤال_الصيادة #عقد_الصيد #FishingKnots"
    },
    {
        "day": 29, "slug": "monthly_recap", "series": "CE MOIS-CI", "language": "FR",
        "objective": "Récapitulatif", "background": "techniques_hero.png",
        "screens": ["30 jours pour mieux préparer", "Sécurité et conditions", "Spots, techniques et communauté", "Continuez à apprendre avec BoosterFish"],
        "voiceover": "Ce mois-ci, nous avons parlé de préparation, sécurité, spots, nœuds et communauté. Dites-nous le sujet que vous voulez approfondir.",
        "caption": "Merci d'avoir suivi ce mois de contenus BoosterFish. Votre question peut devenir le prochain tutoriel : conditions marines, carte, espèces, nœuds, jigging, traîne ou communauté.",
        "cta": "Choisissez le prochain sujet", "hashtags": "#BoosterFish #PecheEnMer #ConseilsPeche #Communaute"
    },
    {
        "day": 30, "slug": "coming_soon", "series": "BIENTÔT", "language": "FR + Darija",
        "objective": "Conversion", "background": "atlantic_shore.png",
        "screens": ["BoosterFish se prépare", "Le test fermé continue", "Nous corrigeons avant le lancement", "تابعونا… الجديد قريب"],
        "voiceover": "Le test fermé continue et chaque retour compte. Nous corrigeons avant le lancement public. تابعونا، الجديد قريب.",
        "caption": "BoosterFish n'est pas encore disponible publiquement. La phase de test fermé sert à vérifier la stabilité et les parcours essentiels. Suivez la page pour connaître l'ouverture officielle sur Google Play.",
        "cta": "Activez les notifications de la page", "hashtags": "#BoosterFish #BientotDisponible #GooglePlay #قريباً"
    },
]


def main() -> None:
    CONTENT.mkdir(parents=True, exist_ok=True)
    subtitles_dir = CONTENT / "captions_srt"
    subtitles_dir.mkdir(parents=True, exist_ok=True)
    (CONTENT / "posts.json").write_text(
        json.dumps(POSTS, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )

    fields = ["day", "slug", "series", "language", "objective", "caption", "cta", "hashtags", "voiceover", "background"]
    with (CONTENT / "calendar_30_days.csv").open("w", encoding="utf-8-sig", newline="") as handle:
        writer = csv.DictWriter(
            handle, fieldnames=fields, extrasaction="ignore", lineterminator="\n"
        )
        writer.writeheader()
        writer.writerows(POSTS)

    calendar = [
        "# Calendrier éditorial BoosterFish — 30 jours",
        "",
        "| Jour | Série | Langue | Objectif | Sujet | CTA |",
        "|---:|---|---|---|---|---|",
    ]
    for post in POSTS:
        calendar.append(
            f"| {post['day']:02d} | {post['series']} | {post['language']} | {post['objective']} | {post['screens'][0]} | {post['cta']} |"
        )
    (CONTENT / "calendar_30_days.md").write_text("\n".join(calendar) + "\n", encoding="utf-8")

    captions = ["# Textes prêts à publier", ""]
    scripts = ["# Scripts vidéo et voix off", ""]
    for post in POSTS:
        captions += [
            f"## Jour {post['day']:02d} — {post['series']}", "", post["caption"], "",
            f"**CTA :** {post['cta']}", "", post["hashtags"], "",
        ]
        scripts += [
            f"## Jour {post['day']:02d} — {post['slug']}", "",
            f"**Langue :** {post['language']}", "",
            "**Durée :** 12 secondes", "",
            f"**Voix off :** {post['voiceover']}", "",
            "**Écrans :**", "",
        ]
        scripts += [f"{idx}. {line}" for idx, line in enumerate(post["screens"], 1)]
        scripts += ["", f"**CTA :** {post['cta']}", ""]
    (CONTENT / "captions_ready_to_post.md").write_text("\n".join(captions), encoding="utf-8")
    (CONTENT / "video_scripts.md").write_text("\n".join(scripts), encoding="utf-8")

    manifest_fields = ["day", "slug", "language", "video", "cover", "subtitle", "caption_source"]
    manifest_rows = []
    for post in POSTS:
        stem = f"{post['day']:02d}_{post['slug']}"
        blocks = []
        for index, line in enumerate(post["screens"]):
            start = index * 3
            end = start + 3
            blocks.append(
                f"{index + 1}\n00:00:{start:02d},000 --> 00:00:{end:02d},000\n{line}\n"
            )
        subtitle_path = subtitles_dir / f"{stem}.srt"
        subtitle_path.write_text("\n".join(blocks), encoding="utf-8")
        manifest_rows.append({
            "day": post["day"],
            "slug": post["slug"],
            "language": post["language"],
            "video": f"exports/reels/{stem}.mp4",
            "cover": f"exports/covers/{stem}.png",
            "subtitle": f"content/captions_srt/{stem}.srt",
            "caption_source": "content/captions_ready_to_post.md",
        })
    with (CONTENT / "delivery_manifest.csv").open("w", encoding="utf-8-sig", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=manifest_fields, lineterminator="\n")
        writer.writeheader()
        writer.writerows(manifest_rows)

    qa = {
        "count": len(POSTS),
        "languages": {lang: sum(p["language"] == lang for p in POSTS) for lang in ("FR", "Darija", "FR + Darija")},
        "facts_used": [
            "Plus de 6 000 spots officiels (catalogue local validé à 6 365 spots)",
            "Cartes hors ligne téléchargeables et activables",
            "Spots personnels et coordonnées privées",
            "Conditions marines, marées, fiches espèces et guides techniques",
            "Communauté avec publication, signalement et blocage",
            "Application actuellement en test fermé Google Play",
        ],
        "claims_avoided": [
            "Aucune garantie de prise",
            "Aucune date de lancement public inventée",
            "Aucune précision météo présentée comme garantie de sécurité",
            "Aucun chiffre concurrent repris dans la communication BoosterFish",
        ],
    }
    (CONTENT / "content_qa.json").write_text(json.dumps(qa, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
