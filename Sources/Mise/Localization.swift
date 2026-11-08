import Foundation

/// Interface language, taken from the system language (Settings › General › Language & Region).
enum Lang: String {
    case en, fr, es, de, ja

    static let current: Lang = {
        for identifier in Locale.preferredLanguages {
            let code = Locale(identifier: identifier).language.languageCode?.identifier
                ?? String(identifier.prefix(2))
            if let lang = Lang(rawValue: code) { return lang }
        }
        return .en
    }()
}

func tr(_ en: String, _ fr: String, _ es: String, _ de: String, _ ja: String) -> String {
    switch Lang.current {
    case .en: return en
    case .fr: return fr
    case .es: return es
    case .de: return de
    case .ja: return ja
    }
}

enum S {
    static var ok: String { tr("OK", "OK", "OK", "OK", "OK") }
    static var checkForUpdates: String { tr("Check for Updates…", "Rechercher les mises à jour…", "Buscar actualizaciones…", "Nach Updates suchen …", "アップデートを確認…") }
    static var new: String { tr("New", "Nouveau", "Nuevo", "Neu", "新規") }
    static var openEllipsis: String { tr("Open…", "Ouvrir…", "Abrir…", "Öffnen …", "開く…") }
    static var save: String { tr("Save", "Enregistrer", "Guardar", "Sichern", "保存") }
    static var saveAs: String { tr("Save As…", "Enregistrer sous…", "Guardar como…", "Sichern unter …", "別名で保存…") }
    static var dontSave: String { tr("Don't Save", "Ne pas enregistrer", "No guardar", "Nicht sichern", "保存しない") }
    static var cancel: String { tr("Cancel", "Annuler", "Cancelar", "Abbrechen", "キャンセル") }
    static var undo: String { tr("Undo", "Annuler", "Deshacer", "Widerrufen", "取り消す") }
    static var redo: String { tr("Redo", "Rétablir", "Rehacer", "Wiederholen", "やり直す") }
    static var duplicate: String { tr("Duplicate", "Dupliquer", "Duplicar", "Duplizieren", "複製") }
    static var deleteDevice: String { tr("Delete Device", "Supprimer l'appareil", "Eliminar dispositivo", "Gerät löschen", "デバイスを削除") }
    static var delete: String { tr("Delete", "Supprimer", "Eliminar", "Löschen", "削除") }
    static var untitled: String { tr("Untitled", "Sans titre", "Sin título", "Unbenannt", "名称未設定") }
    static var mockup: String { tr("Mockup", "Maquette", "Maqueta", "Mockup", "モックアップ") }
    static var edited: String { tr("Edited", "Modifié", "Editado", "Bearbeitet", "編集済み") }
    static var saveChangesTitle: String { tr("Save changes to this mockup?", "Enregistrer les modifications de cette maquette ?", "¿Guardar los cambios de esta maqueta?", "Änderungen an diesem Mockup sichern?", "このモックアップの変更を保存しますか？") }
    static var saveChangesDetail: String { tr("Your changes will be lost if you don't save them.", "Tes modifications seront perdues si tu ne les enregistres pas.", "Los cambios se perderán si no los guardas.", "Deine Änderungen gehen sonst verloren.", "保存しないと変更は失われます。") }
    static var cannotOpen: String { tr("Could not open this file", "Impossible d'ouvrir ce fichier", "No se pudo abrir el archivo", "Datei konnte nicht geöffnet werden", "このファイルを開けませんでした") }
    static var cannotSave: String { tr("Could not save the mockup", "Impossible d'enregistrer la maquette", "No se pudo guardar la maqueta", "Mockup konnte nicht gesichert werden", "モックアップを保存できませんでした") }
    static var notAnImage: String { tr("This file is not an image Mise can read.", "Ce fichier n'est pas une image lisible par Mise.", "Este archivo no es una imagen que Mise pueda leer.", "Diese Datei ist kein lesbares Bild.", "Mise が読み込める画像ではありません。") }
    static var templates: String { tr("Templates", "Modèles", "Plantillas", "Vorlagen", "テンプレート") }
    static var addDevice: String { tr("Add Device", "Ajouter un appareil", "Añadir dispositivo", "Gerät hinzufügen", "デバイスを追加") }
    static var importDesign: String { tr("Import Design", "Importer un design", "Importar diseño", "Design importieren", "デザインを読み込む") }
    static var importDesignEllipsis: String { tr("Import Design…", "Importer un design…", "Importar diseño…", "Design importieren …", "デザインを読み込む…") }
    static var captureWebsite: String { tr("Capture a Website", "Capturer un site web", "Capturar un sitio web", "Website aufnehmen", "Web サイトをキャプチャ") }
    static var captureWebsiteEllipsis: String { tr("Capture a Website…", "Capturer un site web…", "Capturar un sitio web…", "Website aufnehmen …", "Web サイトをキャプチャ…") }
    static var copyImage: String { tr("Copy Image", "Copier l'image", "Copiar imagen", "Bild kopieren", "画像をコピー") }
    static var pasteDesign: String { tr("Paste Design", "Coller un design", "Pegar diseño", "Design einsetzen", "デザインをペースト") }
    static var paste: String { tr("Paste", "Coller", "Pegar", "Einsetzen", "ペースト") }
    static var website: String { tr("Website…", "Site web…", "Sitio web…", "Website …", "Web サイト…") }
    static var export: String { tr("Export", "Exporter", "Exportar", "Exportieren", "書き出す") }
    static var exportEllipsis: String { tr("Export…", "Exporter…", "Exportar…", "Exportieren …", "書き出す…") }
    static var batchExport: String { tr("Export for Several Designs…", "Exporter pour plusieurs designs…", "Exportar para varios diseños…", "Für mehrere Designs exportieren …", "複数のデザインで書き出す…") }
    static var batchHelp: String { tr("The same mockup, one image per design.", "La même maquette, une image par design.", "La misma maqueta, una imagen por diseño.", "Dasselbe Mockup, ein Bild pro Design.", "同じモックアップをデザインごとに書き出します。") }
    static var batchChooseImages: String { tr("Choose the designs to put on the selected device.", "Choisis les designs à placer sur l'appareil sélectionné.", "Elige los diseños para el dispositivo seleccionado.", "Wähle die Designs für das ausgewählte Gerät.", "選択したデバイスに入れるデザインを選んでください。") }
    static var batchChooseFolder: String { tr("Choose where to save the images.", "Choisis où enregistrer les images.", "Elige dónde guardar las imágenes.", "Wähle den Zielordner.", "保存先を選んでください。") }
    static var exportHere: String { tr("Export Here", "Exporter ici", "Exportar aquí", "Hier exportieren", "ここに書き出す") }
    static var exportFailed: String { tr("Could not export the image", "Impossible d'exporter l'image", "No se pudo exportar la imagen", "Bild konnte nicht exportiert werden", "画像を書き出せませんでした") }
    static var inspector: String { tr("Inspector", "Inspecteur", "Inspector", "Informationen", "インスペクタ") }
    static var selectHint: String { tr("Click a device on the canvas to edit it, or drop an image onto it.", "Clique sur un appareil pour le modifier, ou dépose une image dessus.", "Haz clic en un dispositivo para editarlo o suelta una imagen encima.", "Klicke auf ein Gerät oder ziehe ein Bild darauf.", "デバイスをクリックして編集するか、画像をドロップしてください。") }
    static var device: String { tr("Device", "Appareil", "Dispositivo", "Gerät", "デバイス") }
    static var finish: String { tr("Finish", "Finition", "Acabado", "Ausführung", "仕上げ") }
    static var removeDesign: String { tr("Remove Design", "Retirer le design", "Quitar diseño", "Design entfernen", "デザインを外す") }
    static var landscape: String { tr("Landscape", "Paysage", "Horizontal", "Querformat", "横向き") }
    static var photoScreenHint: String { tr("Choose a photo as background, then drag the four corners onto the screen in the photo.", "Choisis une photo en fond, puis place les quatre coins sur l'écran de la photo.", "Elige una foto de fondo y arrastra las cuatro esquinas sobre la pantalla.", "Wähle ein Foto als Hintergrund und ziehe die vier Ecken auf den Bildschirm im Foto.", "写真を背景にして、4 つの角を写真の画面に合わせます。") }
    static var choosePhoto: String { tr("Choose a Photo…", "Choisir une photo…", "Elegir una foto…", "Foto wählen …", "写真を選択…") }
    static var placement: String { tr("Placement", "Position", "Posición", "Platzierung", "配置") }
    static var size: String { tr("Size", "Taille", "Tamaño", "Größe", "サイズ") }
    static var horizontal: String { tr("Horizontal", "Horizontal", "Horizontal", "Horizontal", "横位置") }
    static var vertical: String { tr("Vertical", "Vertical", "Vertical", "Vertikal", "縦位置") }
    static var rotation: String { tr("Rotation", "Rotation", "Rotación", "Drehung", "回転") }
    static var turnSideways: String { tr("Turn", "Pivoter", "Girar", "Schwenken", "左右の角度") }
    static var tilt: String { tr("Tilt", "Incliner", "Inclinar", "Neigen", "上下の角度") }
    static var shadow: String { tr("Shadow", "Ombre", "Sombra", "Schatten", "影") }
    static var reflection: String { tr("Reflection", "Reflet", "Reflejo", "Spiegelung", "反射") }
    static var reflectionHelp: String { tr("For a device facing you, without rotation.", "Pour un appareil de face, sans rotation.", "Para un dispositivo de frente, sin rotación.", "Für ein Gerät von vorne, ohne Drehung.", "正面向きで回転していないデバイス用。") }
    static var resetAngles: String { tr("Face Forward", "Remettre de face", "Poner de frente", "Frontal ausrichten", "正面に戻す") }
    static var bringToFront: String { tr("Bring to Front", "Mettre au premier plan", "Traer al frente", "Nach vorne", "最前面へ") }
    static var sendToBack: String { tr("Send to Back", "Mettre à l'arrière-plan", "Enviar al fondo", "Nach hinten", "最背面へ") }
    static var background: String { tr("Background", "Fond", "Fondo", "Hintergrund", "背景") }
    static var style: String { tr("Style", "Style", "Estilo", "Stil", "スタイル") }
    static var tabDevice: String { tr("Device", "Appareil", "Dispositivo", "Gerät", "デバイス") }
    static var tabScene: String { tr("Scene", "Scène", "Escena", "Szene", "シーン") }
    static var design: String { tr("Design", "Design", "Diseño", "Design", "デザイン") }
    static var chooseImage: String { tr("Choose Image…", "Choisir une image…", "Elegir imagen…", "Bild wählen …", "画像を選択…") }
    static var replaceImage: String { tr("Replace Image…", "Remplacer l'image…", "Reemplazar imagen…", "Bild ersetzen …", "画像を置き換え…") }
    static var otherSources: String { tr("Other Sources", "Autres sources", "Otras fuentes", "Weitere Quellen", "その他") }
    static var pasteImage: String { tr("Paste Image", "Coller l'image", "Pegar imagen", "Bild einsetzen", "画像をペースト") }
    static var fineTuning: String { tr("Fine Tuning", "Réglages fins", "Ajuste fino", "Feinabstimmung", "微調整") }
    static var look: String { tr("Look", "Rendu", "Aspecto", "Darstellung", "見た目") }
    static var arrange: String { tr("Arrange", "Disposer", "Organizar", "Anordnen", "整列") }
    static var angleFront: String { tr("Front", "Face", "Frente", "Vorne", "正面") }
    static var angleLeft: String { tr("Left", "Gauche", "Izquierda", "Links", "左") }
    static var angleRight: String { tr("Right", "Droite", "Derecha", "Rechts", "右") }
    static var angleTilted: String { tr("Tilted", "Incliné", "Inclinado", "Geneigt", "傾き") }
    static var angleIsoLeft: String { tr("Iso Left", "Iso gauche", "Iso izq.", "Iso links", "等角 左") }
    static var angleIsoRight: String { tr("Iso Right", "Iso droite", "Iso der.", "Iso rechts", "等角 右") }
    static var angleFlat: String { tr("Lying Flat", "À plat", "Plano", "Liegend", "平置き") }
    static var angleLeaning: String { tr("Leaning", "Penché", "Apoyado", "Schräg", "斜め") }
    static var angleDynamic: String { tr("Dynamic", "Dynamique", "Dinámico", "Dynamisch", "ダイナミック") }
    static var dropHint: String { tr("Drop your design on the device, or press ⌘V", "Dépose ton design sur l'appareil, ou ⌘V", "Suelta tu diseño en el dispositivo o pulsa ⌘V", "Ziehe dein Design auf das Gerät oder drücke ⌘V", "デザインをデバイスにドロップ、または ⌘V") }
    static var kindPhotoShort: String { tr("Photo", "Photo", "Foto", "Foto", "写真") }
    static var layers: String { tr("Scene", "Scène", "Escena", "Szene", "シーン") }
    static var noLayers: String { tr("Nothing yet", "Rien pour l'instant", "Nada aún", "Noch leer", "まだありません") }
    static var noDesign: String { tr("No design yet", "Pas encore de design", "Sin diseño", "Noch kein Design", "デザインなし") }
    static var emptyTitle: String { tr("Put your design on stage", "Mets ton design en scène", "Pon tu diseño en escena", "Bring dein Design auf die Bühne", "デザインを舞台に") }
    static var emptyText: String { tr("Add a device, or pick a template on the left, then drop a screenshot onto it.", "Ajoute un appareil ou choisis un modèle à gauche, puis dépose une capture dessus.", "Añade un dispositivo o elige una plantilla a la izquierda y suelta una captura encima.", "Füge ein Gerät hinzu oder wähle links eine Vorlage, und ziehe dann einen Screenshot darauf.", "デバイスを追加するか左のテンプレートを選び、スクリーンショットをドロップします。") }
    static var addPhone: String { tr("Phone", "Téléphone", "Teléfono", "Telefon", "スマホ") }
    static var addLaptop: String { tr("Laptop", "Portable", "Portátil", "Laptop", "ノートPC") }
    static var shortBrowser: String { tr("Browser", "Navigateur", "Navegador", "Browser", "ブラウザ") }
    static var shortFloating: String { tr("Floating", "Flottant", "Flotante", "Schwebend", "フロート") }
    static var shortCard: String { tr("Card", "Carte", "Tarjeta", "Karte", "名刺") }
    static var shortPaper: String { tr("Paper", "Feuille", "Hoja", "Blatt", "用紙") }
    static var light: String { tr("Light", "Lumière", "Luz", "Licht", "光") }
    static var lightNone: String { tr("None", "Aucune", "Ninguna", "Keines", "なし") }
    static var lightLeaves: String { tr("Leaves", "Feuillage", "Hojas", "Blätter", "葉の影") }
    static var lightWindow: String { tr("Window", "Fenêtre", "Ventana", "Fenster", "窓") }
    static var lightBlinds: String { tr("Blinds", "Store", "Persiana", "Jalousie", "ブラインド") }
    static var strength: String { tr("Strength", "Intensité", "Intensidad", "Stärke", "強さ") }
    static var bgStudio: String { tr("Studio", "Studio", "Estudio", "Studio", "スタジオ") }
    static var bgSolid: String { tr("Color", "Couleur", "Color", "Farbe", "単色") }
    static var bgGradient: String { tr("Gradient", "Dégradé", "Degradado", "Verlauf", "グラデーション") }
    static var bgMesh: String { tr("Soft Blend", "Fondu doux", "Mezcla suave", "Weicher Verlauf", "ソフトブレンド") }
    static var bgTexture: String { tr("Texture", "Texture", "Textura", "Textur", "テクスチャ") }
    static var bgPhoto: String { tr("Photo", "Photo", "Foto", "Foto", "写真") }
    static var bgTransparent: String { tr("Transparent", "Transparent", "Transparente", "Transparent", "透明") }
    static var color: String { tr("Color", "Couleur", "Color", "Farbe", "色") }
    static var angle: String { tr("Angle", "Angle", "Ángulo", "Winkel", "角度") }
    static var shuffle: String { tr("Shuffle", "Mélanger", "Mezclar", "Mischen", "シャッフル") }
    static var pattern: String { tr("Pattern", "Motif", "Patrón", "Muster", "パターン") }
    static var blur: String { tr("Blur", "Flou", "Desenfoque", "Unschärfe", "ぼかし") }
    static var darken: String { tr("Darken", "Assombrir", "Oscurecer", "Abdunkeln", "暗くする") }
    static var transparentHint: String { tr("Export as PNG or HEIC to keep the transparency.", "Exporte en PNG ou HEIC pour garder la transparence.", "Exporta en PNG o HEIC para conservar la transparencia.", "Als PNG oder HEIC exportieren, um die Transparenz zu behalten.", "透明を保つには PNG か HEIC で書き出してください。") }
    static var texGrain: String { tr("Grain", "Grain", "Grano", "Körnung", "粒子") }
    static var texDots: String { tr("Dots", "Points", "Puntos", "Punkte", "ドット") }
    static var texGrid: String { tr("Grid", "Grille", "Cuadrícula", "Raster", "グリッド") }
    static var texLinen: String { tr("Linen", "Lin", "Lino", "Leinen", "リネン") }
    static var canvas: String { tr("Canvas", "Toile", "Lienzo", "Leinwand", "キャンバス") }
    static var custom: String { tr("Custom", "Personnalisée", "Personalizado", "Eigene", "カスタム") }
    static var widthShort: String { tr("W", "L", "An", "B", "幅") }
    static var heightShort: String { tr("H", "H", "Al", "H", "高さ") }
    static var format: String { tr("Format", "Format", "Formato", "Format", "形式") }
    static var resolution: String { tr("Resolution", "Résolution", "Resolución", "Auflösung", "解像度") }
    static var width: String { tr("Width", "Largeur", "Ancho", "Breite", "幅") }
    static var desktopWidth: String { tr("Computer", "Ordinateur", "Ordenador", "Computer", "コンピュータ") }
    static var fullPage: String { tr("Whole page (not just the first screen)", "Page entière (pas seulement le premier écran)", "Página completa (no solo la primera pantalla)", "Ganze Seite (nicht nur der erste Bildschirm)", "ページ全体（最初の画面だけでなく）") }
    static var capture: String { tr("Capture", "Capturer", "Capturar", "Aufnehmen", "キャプチャ") }
    static var captureHint: String { tr("The page loads privately: no cookies, no history. Pages that need a login can't be captured.", "La page est chargée en privé : ni cookies ni historique. Les pages qui demandent une connexion ne peuvent pas être capturées.", "La página se carga en privado: sin cookies ni historial.", "Die Seite wird privat geladen: keine Cookies, kein Verlauf.", "ページはプライベートに読み込まれます（Cookie や履歴は残りません）。") }
    static var invalidAddress: String { tr("Enter a web address (https://…).", "Saisis une adresse web (https://…).", "Escribe una dirección web (https://…).", "Gib eine Webadresse ein (https://…).", "Web アドレス（https://…）を入力してください。") }
    static var captureTimeout: String { tr("The page took too long to load.", "La page a mis trop de temps à charger.", "La página tardó demasiado en cargar.", "Die Seite hat zu lange geladen.", "ページの読み込みに時間がかかりすぎました。") }
    static var captureFailed: String { tr("The page could not be captured.", "La page n'a pas pu être capturée.", "No se pudo capturar la página.", "Die Seite konnte nicht aufgenommen werden.", "ページをキャプチャできませんでした。") }
    static var captureCancelled: String { tr("Capture cancelled.", "Capture annulée.", "Captura cancelada.", "Aufnahme abgebrochen.", "キャプチャを中止しました。") }
    static var kindPhone: String { tr("Phone", "Téléphone", "Teléfono", "Telefon", "スマートフォン") }
    static var kindAndroid: String { tr("Phone (Android style)", "Téléphone (style Android)", "Teléfono (estilo Android)", "Telefon (Android-Stil)", "スマートフォン（Android 風）") }
    static var kindTablet: String { tr("Tablet", "Tablette", "Tableta", "Tablet", "タブレット") }
    static var kindLaptop: String { tr("Laptop", "Ordinateur portable", "Portátil", "Laptop", "ノートパソコン") }
    static var kindDesktop: String { tr("Display", "Écran", "Monitor", "Monitor", "ディスプレイ") }
    static var kindWatch: String { tr("Watch", "Montre", "Reloj", "Uhr", "ウォッチ") }
    static var kindBrowser: String { tr("Browser Window", "Fenêtre de navigateur", "Ventana del navegador", "Browserfenster", "ブラウザウインドウ") }
    static var kindFloating: String { tr("Floating Screen", "Écran flottant", "Pantalla flotante", "Schwebender Bildschirm", "フローティング画面") }
    static var kindCard: String { tr("Business Card", "Carte de visite", "Tarjeta de visita", "Visitenkarte", "名刺") }
    static var kindPoster: String { tr("Poster", "Affiche", "Póster", "Poster", "ポスター") }
    static var kindBook: String { tr("Book", "Livre", "Libro", "Buch", "本") }
    static var kindPaper: String { tr("Sheet of Paper", "Feuille de papier", "Hoja de papel", "Blatt Papier", "用紙") }
    static var kindPhotoScreen: String { tr("Screen in a Photo", "Écran dans une photo", "Pantalla en una foto", "Bildschirm in einem Foto", "写真の中の画面") }
    static var finishGraphite: String { tr("Graphite", "Graphite", "Grafito", "Graphit", "グラファイト") }
    static var finishSilver: String { tr("Silver", "Argent", "Plata", "Silber", "シルバー") }
    static var finishGold: String { tr("Gold", "Or", "Oro", "Gold", "ゴールド") }
    static var finishBlue: String { tr("Blue", "Bleu", "Azul", "Blau", "ブルー") }
    static var finishWhite: String { tr("White", "Blanc", "Blanco", "Weiß", "ホワイト") }
    static var finishSpaceGray: String { tr("Space Gray", "Gris sidéral", "Gris espacial", "Space Grau", "スペースグレイ") }
    static var finishMidnight: String { tr("Midnight", "Minuit", "Medianoche", "Mitternacht", "ミッドナイト") }
    static var finishLight: String { tr("Light", "Clair", "Claro", "Hell", "ライト") }
    static var finishDark: String { tr("Dark", "Sombre", "Oscuro", "Dunkel", "ダーク") }
    static var finishPaper: String { tr("White Paper", "Papier blanc", "Papel blanco", "Weißes Papier", "白い紙") }
    static var finishKraft: String { tr("Kraft", "Kraft", "Kraft", "Kraftpapier", "クラフト紙") }
    static var finishCloth: String { tr("Cloth", "Toile", "Tela", "Leinen", "クロス") }
    static var finishNone: String { tr("No Border", "Sans bordure", "Sin borde", "Ohne Rand", "枠なし") }
    static var tplPhone: String { tr("Phone", "Téléphone", "Teléfono", "Telefon", "スマートフォン") }
    static var tplPhoneTilted: String { tr("Phone in 3D", "Téléphone en 3D", "Teléfono en 3D", "Telefon in 3D", "3D のスマートフォン") }
    static var tplThreePhones: String { tr("Three Phones", "Trois téléphones", "Tres teléfonos", "Drei Telefone", "3 台のスマートフォン") }
    static var tplLaptopPhone: String { tr("Laptop and Phone", "Portable et téléphone", "Portátil y teléfono", "Laptop und Telefon", "ノートと電話") }
    static var tplLaptop: String { tr("Laptop", "Ordinateur portable", "Portátil", "Laptop", "ノートパソコン") }
    static var tplLaptopAngle: String { tr("Laptop at an Angle", "Portable de biais", "Portátil en ángulo", "Laptop schräg", "斜めのノート") }
    static var tplDesktop: String { tr("Display", "Écran", "Monitor", "Monitor", "ディスプレイ") }
    static var tplTabletPhone: String { tr("Tablet and Phone", "Tablette et téléphone", "Tableta y teléfono", "Tablet und Telefon", "タブレットと電話") }
    static var tplWatch: String { tr("Watch", "Montre", "Reloj", "Uhr", "ウォッチ") }
    static var tplBrowser: String { tr("Browser Window", "Fenêtre de navigateur", "Ventana del navegador", "Browserfenster", "ブラウザ") }
    static var tplFloating: String { tr("Floating Screen", "Écran flottant", "Pantalla flotante", "Schwebender Bildschirm", "フローティング画面") }
    static var tplCard: String { tr("Business Card", "Carte de visite", "Tarjeta de visita", "Visitenkarte", "名刺") }
    static var tplPoster: String { tr("Poster", "Affiche", "Póster", "Poster", "ポスター") }
    static var tplBook: String { tr("Book", "Livre", "Libro", "Buch", "本") }
    static var tplStory: String { tr("Story (9:16)", "Story (9:16)", "Historia (9:16)", "Story (9:16)", "ストーリー (9:16)") }
    static var tplSquare: String { tr("Square Post", "Post carré", "Publicación cuadrada", "Quadratischer Post", "正方形の投稿") }
    static var tplAndroid: String { tr("Android Phone", "Téléphone Android", "Teléfono Android", "Android-Smartphone", "Android スマートフォン") }
    static var tplTwoPhones: String { tr("iOS & Android", "iOS et Android", "iOS y Android", "iOS & Android", "iOS と Android") }
    static var tplFan: String { tr("Phone Fan", "Éventail de téléphones", "Abanico de teléfonos", "Smartphone-Fächer", "スマートフォンの扇形") }
    static var tplReflection: String { tr("Reflection", "Reflet", "Reflejo", "Spiegelung", "反射") }
    static var tplFlatLay: String { tr("Flat Lay", "À plat", "Vista cenital", "Flat Lay", "フラットレイ") }
    static var tplTabletLandscape: String { tr("Tablet, Landscape", "Tablette paysage", "Tableta horizontal", "Tablet quer", "タブレット(横)") }
    static var tplTabletAngle: String { tr("Tablet in Perspective", "Tablette en perspective", "Tableta en perspectiva", "Tablet perspektivisch", "タブレット(遠近)") }
    static var tplWatchPhone: String { tr("Watch & Phone", "Montre et téléphone", "Reloj y teléfono", "Uhr & Smartphone", "ウォッチとスマートフォン") }
    static var tplEcosystem: String { tr("Every Screen", "Tous les écrans", "Todas las pantallas", "Alle Bildschirme", "すべての画面") }
    static var tplResponsive: String { tr("Responsive Website", "Site responsive", "Web adaptable", "Responsive Website", "レスポンシブサイト") }
    static var tplBanner: String { tr("Header Banner", "Bannière d'en-tête", "Banner de cabecera", "Header-Banner", "ヘッダーバナー") }
    static var tplAppStore: String { tr("App Store Screenshot", "Capture App Store", "Captura de App Store", "App-Store-Screenshot", "App Store スクリーンショット") }
    static var tplLetter: String { tr("Letter Sheet", "Feuille A4", "Hoja de carta", "Briefbogen", "レターシート") }
    static var tplStationery: String { tr("Stationery Set", "Papeterie", "Papelería", "Geschäftsausstattung", "ステーショナリー") }
    static var tplPhoto: String { tr("Your Photo", "Ta photo", "Tu foto", "Dein Foto", "あなたの写真") }
    static func colorNumber(_ n: Int) -> String { tr("Color \(n)", "Couleur \(n)", "Color \(n)", "Farbe \(n)", "色 \(n)") }
    static func batchFailures(_ n: Int) -> String { tr("\(n) image(s) could not be exported", "\(n) image(s) n'ont pas pu être exportée(s)", "\(n) imagen(es) no se pudieron exportar", "\(n) Bild(er) konnten nicht exportiert werden", "\(n) 枚の画像を書き出せませんでした") }
    // MARK: Updates
    static var updateFailed: String { tr("Update failed", "La mise à jour a échoué", "Error al actualizar", "Aktualisierung fehlgeschlagen", "アップデートに失敗しました") }
    static var upToDate: String { tr("Mise is up to date", "Mise est à jour", "Mise está actualizado", "Mise ist aktuell", "Mise は最新です") }
    static func upToDateDetail(_ v: String) -> String { tr("You have the latest version (\(v)).", "Tu as la dernière version (\(v)).", "Tienes la última versión (\(v)).", "Du hast die neueste Version (\(v)).", "最新バージョン (\(v)) です。") }
    static func updateAvailable(_ v: String) -> String { tr("Mise \(v) is available", "Mise \(v) est disponible", "Mise \(v) está disponible", "Mise \(v) ist verfügbar", "Mise \(v) が利用可能です") }
    static func updateAvailableDetail(current: String) -> String { tr("You have version \(current). The update installs in a few seconds and Mise restarts.", "Tu as la version \(current). La mise à jour s'installe en quelques secondes, puis Mise redémarre.", "Tienes la versión \(current). La actualización se instala en unos segundos y Mise se reinicia.", "Du hast Version \(current). Das Update wird in Sekunden installiert, dann startet Mise neu.", "現在のバージョンは \(current) です。数秒でインストールされ、Mise が再起動します。") }
    static var installAndRestart: String { tr("Install and Restart", "Installer et redémarrer", "Instalar y reiniciar", "Installieren und neu starten", "インストールして再起動") }
    static var later: String { tr("Later", "Plus tard", "Más tarde", "Später", "後で") }
    static var skipVersion: String { tr("Skip This Version", "Ignorer cette version", "Omitir esta versión", "Diese Version überspringen", "このバージョンをスキップ") }
    static var downloadingUpdate: String { tr("Downloading the update…", "Téléchargement de la mise à jour…", "Descargando la actualización…", "Update wird geladen …", "アップデートをダウンロード中…") }
    static var installingUpdate: String { tr("Installing…", "Installation…", "Instalando…", "Installation …", "インストール中…") }
    static var restarting: String { tr("Restarting Mise…", "Redémarrage de Mise…", "Reiniciando Mise…", "Mise startet neu …", "Mise を再起動中…") }
    static var updateCheckFailed: String { tr("Could not check for updates", "Impossible de vérifier les mises à jour", "No se pudieron buscar actualizaciones", "Updates konnten nicht geprüft werden", "アップデートを確認できませんでした") }
    static var downloadManually: String { tr("Download Manually", "Télécharger manuellement", "Descargar manualmente", "Manuell laden", "手動でダウンロード") }
    static var updateNoAsset: String { tr("The release has no .zip file.", "La version publiée ne contient pas de fichier .zip.", "La versión no contiene un archivo .zip.", "Die Version enthält keine .zip-Datei.", "リリースに .zip ファイルがありません。") }
    static var updateBadArchive: String { tr("The downloaded archive is damaged.", "L'archive téléchargée est endommagée.", "El archivo descargado está dañado.", "Das geladene Archiv ist beschädigt.", "ダウンロードしたアーカイブが破損しています。") }
    static var updateBadSignature: String { tr("The downloaded app is not signed like this one: it was not installed.", "L'app téléchargée n'a pas la même signature que celle-ci : elle n'a pas été installée.", "La app descargada no tiene la misma firma: no se instaló.", "Die geladene App ist anders signiert und wurde nicht installiert.", "ダウンロードしたアプリの署名が一致しないため、インストールしませんでした。") }
    static func updateCannotReplace(_ folder: String) -> String { tr("Mise cannot write to \(folder).", "Mise ne peut pas écrire dans \(folder).", "Mise no puede escribir en \(folder).", "Mise kann nicht in \(folder) schreiben.", "Mise は \(folder) に書き込めません。") }

}
