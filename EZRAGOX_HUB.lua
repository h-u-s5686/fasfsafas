--[[
    EZRAGOX HUB  •  Türk Troll Scripti  •  v6.7 (FPS + Coin Farm Güncellemesi)
]]

--[[
    ╔══════════════════════════════════════════════════════════════════════════╗
    ║  YAPAY ZEKA / DÜZENLEYEN KİŞİ İÇİN ZORUNLU NOT — LOCAL DEĞİŞKEN SINIRI   ║
    ╚══════════════════════════════════════════════════════════════════════════╝

    SORUN: Lua/Luau'da BİR FONKSİYON İÇİNDE AYNI ANDA EN FAZLA 200 `local` değişken
    olabilir (local function, for döngüsü değişkenleri, fonksiyon parametreleri dahil;
    iç içe blokların local'leri de o anda aktifse sayılır). Sınır aşılırsa script
    DERLENEMEZ ve HİÇBİR ŞEY ÇALIŞMAZ (menü açılmaz, hata bile görünmeyebilir).
    Bu script bir kez tam olarak bu yüzden açılmadı. Söz dizimi hatası DEĞİLDİR,
    o yüzden `end` / parantez kontrolü yapınca "sorun yok" çıkar; asıl sebep budur.

    MEVCUT DURUM (yaklaşık, sınır 200):
      • Ana blok (dosyanın en dışı) .......... ~196  → NEREDEYSE DOLU, buraya YENİ local EKLEME
      • MM2 bölümü (;(function() ... end)()) .. ~192  → NEREDEYSE DOLU, buraya da EKLEME
    Yani yeni bir `local` eklemek script'i yeniden bozabilir.

    YENİ ÖZELLİK / DÜZENLEME YAPARKEN KURALLAR:
      1) Yeni özelliği kendi fonksiyonunun içine yaz; local'leri orada tanımla:
             ;(function()
                 local a, b, c = ...   -- bunlar ana sayaçtan sayılmaz
                 ...
             end)()
         Başına `;` KOYMAYI UNUTMA (önceki satır `)` ile bitiyorsa Lua iki satırı
         birleştirip çağrı sanır ve bozulur).
      2) Dışarıyla paylaşılacak değerleri yeni local yerine mevcut tablolara koy
         (örn. SFX.yeniDeger = ... , Settings.YeniAyar = ...).
      3) Küçük yardımcıları ayrı local function yapmak yerine tabloya ata:
             SFX.yardimci = function(...) ... end
      4) Mümkünse tek kullanımlık local'leri `do ... end` bloğuna al; blok bitince
         sayaçtan düşer (ama blok içindeyken hâlâ sayılır; sorun büyükse fonksiyona sar).
      5) Fonksiyona sararken içindeki `return` / `break`'in dışarıdaki akışı
         etkilemediğinden emin ol (return artık sadece o iç fonksiyondan çıkar).
      6) Düzenlemeden sonra mutlaka kontrol et: en yoğun noktada aktif local sayısı
         190'ı geçmemeli. Eski kodu silme/bozma; sadece sarmala veya tabloya taşı.
      7) Toggle isimleri (örn. "Sol Tıkla Keskin Vuruş (Silah Elindeyken)") hem kayıtlı
         ayar anahtarı hem çeviri anahtarıdır; adı değiştirirsen ikisini de güncelle.

    ÖZET: "Script açılmıyor" denirse önce `local` sayısına bak (200 sınırı), sonra
    söz dizimine.
]]

-- Çakışma önleyici: Önceki çalışan sürümü tamamen temizle
if getgenv then
    if getgenv().EZRAGOX_HUB_CLEANUP then
        pcall(getgenv().EZRAGOX_HUB_CLEANUP)
    end
end

local Players = game:GetService("Players")

while not Players.LocalPlayer do
    task.wait(0.1)
end

local LocalPlayer = Players.LocalPlayer
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local Stats = game:GetService("Stats")
local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")

local DISCORD_URL = "https://discord.gg/gDdP7h5NS"

-- Discord bağlantısı yalnızca ana sayfadaki Premium çağrısına tıklanınca açılır.

local Camera = workspace.CurrentCamera or workspace:FindFirstChildOfClass("Camera")
local GUI_NAME = "EZRAGOX_HUB"

local alive = true
local conns = {}
local shieldCleanup = nil -- Kalkan özelliği temizliği (closeAll içinde çağrılır)
local skyCleanup = nil -- Gökyüzü özelliği temizliği (closeAll içinde çağrılır)
local makeAntiFlingToggle = nil -- Anti-Fling: Özellikler VE MM2 sayfasinda ayni ozelligi acan toggle uretici
local antiFlingCleanup = nil -- Anti-Fling temizligi (closeAll icinde cagrilir)
local function bind(signal, fn)
    local c = signal:Connect(fn)
    conns[#conns + 1] = c
    return c
end

---------------------------------------------------------
-- 0. TEMİZLİK + OTOMATİK KAYIT (CONFIG) SİSTEMİ
---------------------------------------------------------
local function cleanOld(container)
    if not container then return end
    pcall(function()
        for _, n in ipairs({"EZRAGOX_TrollHub", GUI_NAME}) do
            local old = container:FindFirstChild(n)
            if old then old:Destroy() end
        end
    end)
end
cleanOld(CoreGui)
cleanOld(LocalPlayer:FindFirstChildOfClass("PlayerGui"))
if gethui then pcall(function() cleanOld(gethui()) end) end
for _, n in ipairs({"EZRAGOX_Blur", "EZRAGOX_CC", "EZRAGOX_Bloom"}) do
    local o = Lighting:FindFirstChild(n)
    if o then o:Destroy() end
end

local CONFIG_FILE = "ezragox_hub_config.json"
local Settings = {
    Blur = true,
    Sound = true,
    NotificationVolume = 35,
    Scale = 1,
    ToggleKey = Enum.KeyCode.G,
    SpeedVal = 48,
    FlyKey = Enum.KeyCode.F,
    FlySpeed = 50,
    Language = "TR",
    ToggleStates = {},
    SliderValues = {},
    MM2ShootKey = Enum.KeyCode.Z,   -- MM2: katile keskin vuruş tuşu
    MM2GunKey = Enum.KeyCode.X,     -- MM2: düşen silaha ışınlanma tuşu
    MM2KnifeKey = Enum.KeyCode.C,   -- MM2: en yakındakine bıçak atma tuşu
    MM2KnifeMouse = false,          -- MM2: bıçak atma için fare tuşu (varsa)
    MM2ShootMouse = false,          -- MM2: keskin vuruş için fare tuşu (varsa)
    MM2GunMouse = false,            -- MM2: silaha ışınlanma için fare tuşu (varsa)
    MM2InvisKey = Enum.KeyCode.V,   -- MM2: görünmezlik aç/kapa tuşu
    MM2InvisMouse = false,          -- MM2: görünmezlik için fare tuşu (orta tık)
    MM2Lobby = false,               -- MM2: kaydedilen lobi konumu {x=,y=,z=}
    MM2GunSound = 0,                -- MM2: seçili silah sesi (0 = orijinal ses)
    SelectedSkyId = nil,             -- Son seçilen gökyüzü
    Aura = nil,                      -- Son seçilen aura (id)
    VotePads = nil,                  -- MM2: oylama pedleri (eski kayıtlardan taşınır)
    AnimPack = nil,                  -- Son seçilen animasyon paketi (ad)
    TagIdx = nil,                    -- Son seçilen sahte rütbe sırası
    CursorStyle = "🎯",
    CursorSize = 32,
    CursorSpin = false,
}

local function saveConfig()
    pcall(function()
        if writefile then
            local data = {
                Blur = Settings.Blur,
                Sound = Settings.Sound,
                NotificationVolume = Settings.NotificationVolume,
                Scale = Settings.Scale,
                ToggleKey = Settings.ToggleKey.Name,
                SpeedVal = Settings.SpeedVal,
                FlyKey = Settings.FlyKey.Name,
                FlySpeed = Settings.FlySpeed,
                Language = Settings.Language,
                ToggleStates = Settings.ToggleStates,
                SliderValues = Settings.SliderValues,
                MM2ShootKey = Settings.MM2ShootKey.Name,
                MM2GunKey = Settings.MM2GunKey.Name,
                MM2KnifeKey = Settings.MM2KnifeKey.Name,
                MM2KnifeMouse = Settings.MM2KnifeMouse and Settings.MM2KnifeMouse.Name or nil,
                MM2ShootMouse = Settings.MM2ShootMouse and Settings.MM2ShootMouse.Name or nil,
                MM2GunMouse = Settings.MM2GunMouse and Settings.MM2GunMouse.Name or nil,
                MM2InvisKey = Settings.MM2InvisKey.Name,
                MM2InvisMouse = Settings.MM2InvisMouse and Settings.MM2InvisMouse.Name or nil,
                MM2Lobby = type(Settings.MM2Lobby) == "table" and Settings.MM2Lobby or nil,
                MM2GunSound = Settings.MM2GunSound,
                SelectedSkyId = Settings.SelectedSkyId,
                Aura = Settings.Aura,
                VotePads = type(Settings.VotePads) == "table" and Settings.VotePads or nil,
                AnimPack = Settings.AnimPack,
                TagIdx = Settings.TagIdx,
                CursorStyle = Settings.CursorStyle,
                CursorSize = Settings.CursorSize,
                CursorSpin = Settings.CursorSpin,
                WinW = Settings.WinW,
                WinH = Settings.WinH,
            }
            writefile(CONFIG_FILE, HttpService:JSONEncode(data))
        end
    end)
end

local function loadConfig()
    pcall(function()
        if readfile and isfile and isfile(CONFIG_FILE) then
            local data = HttpService:JSONDecode(readfile(CONFIG_FILE))
            if data then
                if data.Blur ~= nil then Settings.Blur = data.Blur end
                if data.Sound ~= nil then Settings.Sound = data.Sound end
                if data.NotificationVolume ~= nil then Settings.NotificationVolume = math.clamp(tonumber(data.NotificationVolume) or 35, 0, 100) end
                if data.Scale ~= nil then Settings.Scale = data.Scale end
                if data.ToggleKey and Enum.KeyCode[data.ToggleKey] then Settings.ToggleKey = Enum.KeyCode[data.ToggleKey] end
                if data.SpeedVal ~= nil then Settings.SpeedVal = data.SpeedVal end
                if data.FlyKey and Enum.KeyCode[data.FlyKey] then Settings.FlyKey = Enum.KeyCode[data.FlyKey] end
                if data.FlySpeed ~= nil then Settings.FlySpeed = data.FlySpeed end
                if data.Language == "EN" or data.Language == "TR" then Settings.Language = data.Language end
                if type(data.ToggleStates) == "table" then Settings.ToggleStates = data.ToggleStates end
                if type(data.SliderValues) == "table" then Settings.SliderValues = data.SliderValues end
                if data.MM2ShootKey and Enum.KeyCode[data.MM2ShootKey] then Settings.MM2ShootKey = Enum.KeyCode[data.MM2ShootKey] end
                if data.MM2GunKey and Enum.KeyCode[data.MM2GunKey] then Settings.MM2GunKey = Enum.KeyCode[data.MM2GunKey] end
                if data.MM2KnifeKey and Enum.KeyCode[data.MM2KnifeKey] then Settings.MM2KnifeKey = Enum.KeyCode[data.MM2KnifeKey] end
                if data.MM2KnifeMouse and Enum.UserInputType[data.MM2KnifeMouse] then Settings.MM2KnifeMouse = Enum.UserInputType[data.MM2KnifeMouse] end
                if data.MM2ShootMouse and Enum.UserInputType[data.MM2ShootMouse] then Settings.MM2ShootMouse = Enum.UserInputType[data.MM2ShootMouse] end
                if data.MM2GunMouse and Enum.UserInputType[data.MM2GunMouse] then Settings.MM2GunMouse = Enum.UserInputType[data.MM2GunMouse] end
                if data.MM2InvisKey and Enum.KeyCode[data.MM2InvisKey] then Settings.MM2InvisKey = Enum.KeyCode[data.MM2InvisKey] end
                if data.MM2InvisMouse and Enum.UserInputType[data.MM2InvisMouse] then Settings.MM2InvisMouse = Enum.UserInputType[data.MM2InvisMouse] end
                if tonumber(data.MM2GunSound) then Settings.MM2GunSound = math.clamp(math.floor(tonumber(data.MM2GunSound)), 0, 5) end
                if tonumber(data.SelectedSkyId) then Settings.SelectedSkyId = math.floor(tonumber(data.SelectedSkyId)) end
                if type(data.Aura) == "string" then Settings.Aura = data.Aura end
                if type(data.VotePads) == "table" then Settings.VotePads = data.VotePads end
                if type(data.AnimPack) == "string" then Settings.AnimPack = data.AnimPack end
                if tonumber(data.TagIdx) then Settings.TagIdx = math.floor(tonumber(data.TagIdx)) end
                if type(data.CursorStyle) == "string" then Settings.CursorStyle = data.CursorStyle end
                if tonumber(data.CursorSize) then Settings.CursorSize = math.clamp(math.floor(tonumber(data.CursorSize)), 18, 64) end
                if type(data.CursorSpin) == "boolean" then Settings.CursorSpin = data.CursorSpin end
                if tonumber(data.WinW) then Settings.WinW = math.clamp(math.floor(tonumber(data.WinW)), 600, 2000) end
                if tonumber(data.WinH) then Settings.WinH = math.clamp(math.floor(tonumber(data.WinH)), 440, 1400) end
                if type(data.MM2Lobby) == "table" and tonumber(data.MM2Lobby.x) and tonumber(data.MM2Lobby.y) and tonumber(data.MM2Lobby.z) then
                    Settings.MM2Lobby = data.MM2Lobby
                end
            end
        end
    end)
end
loadConfig()

local listeningForKey = false
local updateKeyTextCallback = nil
local listeningFlyKey = false
local updateFlyKeyTextCallback = nil

-- Dil sistemi: arayüz metinlerini kayıt altında tutar ve seçim değişince yeniler.
local UI_TEXT_OBJECTS = {}
-- Performans: nesne -> kayıt indeksi ve çeviri önbelleği (liste taraması / her çağrıda sıralama yok)
UI_TEXT_OBJECTS.idx = setmetatable({}, {__mode = "k"})
UI_TEXT_OBJECTS.trc, UI_TEXT_OBJECTS.trn = {}, 0
local EN_TEXT = {
    ["EKRAN GENİŞLETME"] = "SCREEN EXPANSION",
    ["FLING  •  İSİM YAZ / TIKLA / DOKUN"] = "FLING • ENTER NAME / CLICK / TAP",
    ["MERMİ İZİ  •  VURUŞ EFEKTLERİ"] = "BULLET TRAIL • HIT EFFECTS",
    ["↔️  Genişlik"] = "↔️ Width",
    ["↕️  Yazı Yüksekliği  (isim altına denk getir)"] = "↕️ Text Height (align below name)",
    ["⏱️  İz Süresi"] = "⏱️ Trail Duration",
    ["⏹️  Önizleme Sesini Durdur"] = "⏹️ Stop Preview Sound",
    ["♻️  Animasyonları Sıfırla (Orijinal)"] = "♻️ Reset Animations (Default)",
    ["♻️  Aurayı Kapat"] = "♻️ Disable Aura",
    ["⚡  Efekt Testi (Önüne Şimşek Çaktır)"] = "⚡ Test Effect (Strike Lightning in Front)",
    ["⚡  Vuruş Aralığı (düşük = hızlı)"] = "⚡ Hit Interval (lower = faster)",
    ["⚡  Şimşek Çarpması (Katil Vurulunca)"] = "⚡ Lightning Strike (When Killer Is Hit)",
    ["✨  AURA EFEKTLERİ"] = "✨ AURA EFFECTS",
    ["✨  Yeni Efektleri Dene (Ateş • Buz • Sütun • Havai Fişek)"] = "✨ Try New Effects (Fire • Ice • Pillar • Fireworks)",
    ["❄️  Buz Parçalanması (Katil Vurulunca)"] = "❄️ Ice Shatter (When Killer Is Hit)",
    ["🌀  Uzak Hedefe Işınlanıp Vur  (Kapalıysa Yerinde Vurur)"] = "🌀 Teleport to Distant Target and Hit (Off = Hit in Place)",
    ["🌈  Mermi İzi (RGB)"] = "🌈 Bullet Trail (RGB)",
    ["🌠  "] = "🌠 ",
    ["🌠  Enerji Sütunu (Katil Vurulunca)"] = "🌠 Energy Pillar (When Killer Is Hit)",
    ["🎆  Havai Fişek (Katil Vurulunca)"] = "🎆 Fireworks (When Killer Is Hit)",
    ["🎭  "] = "🎭 ",
    ["🎭  PREMİUM ANİMASYON PAKETLERİ"] = "🎭 PREMIUM ANIMATION PACKS",
    ["🎯  Headshot Efekti Önizle • %20 Ses"] = "🎯 Preview Headshot Effect • 20% Volume",
    ["🏠  Lobiye Işınlan"] = "🏠 Teleport to Lobby",
    ["🏷️  Rütbe: "] = "🏷️ Rank: ",
    ["🐢  Farm Hızı"] = "🐢 Farm Speed",
    ["👑  PREMİUM KIYAFET DEĞİŞTİRİCİ"] = "👑 PREMIUM OUTFIT CHANGER",
    ["💀  Herkesi Öldür (Kill All)"] = "💀 Kill Everyone (Kill All)",
    ["💥  Seçili Oyuncuyu Fırlat (1000x)"] = "💥 Fling Selected Player (1000x)",
    ["💥  Vuruş Animasyonu (Katil Vurulunca)"] = "💥 Hit Animation (When Killer Is Hit)",
    ["💪  İtme Gücü"] = "💪 Knockback Strength",
    ["📌  Şu Anki Konumu Lobi Olarak Kaydet"] = "📌 Save Current Position as Lobby",
    ["📍  Silaha Işınlan (Şimdi)"] = "📍 Teleport to Gun (Now)",
    ["📏  Kaçış Mesafesi"] = "📏 Escape Distance",
    ["🔊  Şimşek Sesi (0 = Sessiz)"] = "🔊 Lightning Sound (0 = Silent)",
    ["🔍  Oylama Tara (F9'a Rapor Yaz)"] = "🔍 Scan Vote (Write Report to F9)",
    ["🔍  Sayacı Yeniden Bul / Teşhis"] = "🔍 Find Counter Again / Diagnose",
    ["🔥  Ateş Patlaması (Katil Vurulunca)"] = "🔥 Fire Burst (When Killer Is Hit)",
    ["🔪  Seçili Oyuncuyu Öldür"] = "🔪 Kill Selected Player",
    ["🔫  Keskin Vuruş (Katil / Zombi) — Şimdi"] = "🔫 Sharp Shot (Killer / Zombie) — Now",
    ["🔪  Bıçak Atma  (Tuşla En Yakındakine Hızlıca At)"] = "🔪 Knife Throw  (Hotkey, Nearest Player, Fast)",
    ["🔪  En Yakındakine Bıçak At — Şimdi"] = "🔪 Throw Knife at Nearest — Now",
    ["🔫  Silahı Önceden Ele Al (Sheriff Olunca Otomatik)"] = "🔫 Pre-Equip Gun (Auto When Sheriff)",
    ["🔁  Iskalarsa Otomatik Tekrar Vur"] = "🔁 Auto Re-Shoot If Missed",
    ["🎯  Nişan Öngörüsü (%)  •  mermi arkada kalırsa artır"] = "🎯  Aim Lead (%)  •  raise if shots land behind",
    ["🔍  Katil Gücü Teşhisi (F9'a Rapor Yaz)"] = "🔍 Murderer Power Diagnostic (Write Report to F9)",
    ["🖱️  Sol Tıkla Keskin Vuruş (Silah Elindeyken)"] = "🖱️ Sharp Shot on Left Click (Gun Equipped)",
    ["GÖRÜNMEZLİK"] = "INVISIBILITY",
    ["👻  Görünmezlik (Karakterim Görünmez)"] = "👻 Invisibility (My Character Hidden)",
    ["Görünmezlik Tuşu"] = "Invisibility Key",
    ["🏷️  Script Kullanıcı Logosu (Aynı Scripti Kullananlar)"] = "🏷️ Script User Logo (Others Using This Script)",
    ["🖥️  Ekranı Yatay Genişlet (Geniş Ekran)"] = "🖥️ Expand Screen Horizontally (Widescreen)",
    ["OYUNCU ÇARPIŞMASI"] = "PLAYER COLLISION",
    ["👥  Oyuncuların İçinden Geç  (İtilme Engeli)"] = "👥  Walk Through Players  (No Pushing)",
    ["🗺️  Haritaya Işınlan"] = "🗺️ Teleport to Map",
    ["🛡️  Anti-Fling (Savrulma Engelleyici - En Guclu Mod)"] = "🛡️ Anti-Fling (Knockback Protection - Strongest Mode)",
    ["🫸  Dokunduğun Kişiyi İleri İt"] = "🫸 Push the Person You Touch Forward",
    ["Premium"]="Premium", ["Ayarlar"]="Settings", ["Yönetim"]="Admin",
    ["KONTROL"]="CONTROLS", ["GÖRÜNÜM"]="APPEARANCE", ["SES"]="SOUND", ["DİĞER"]="OTHER",
    ["Menü Tuşu"]="Menu Key", ["Bulanık arka plan"]="Blurred Background",
    ["Menü boyutu"]="Menu Size", ["Ses efektleri"]="Sound Effects",
    ["Menüyü küçült"]="Minimize Menu", ["Arayüzü tamamen kapat"]="Close Interface",
    ["Dil"]="Language", ["Türkçe"]="Turkish", ["İngilizce"]="English",
    ["Tuşa basın..."]="Press a key...", ["menüyü aç / kapat"]="toggle menu",
    ["KARAKTER ÖZELLİKLERİ"]="CHARACTER FEATURES",
    ["👻  Hayalet Modu (Görünmezlik)"]="👻  Ghost Mode (Invisibility)",
    ["🛡️  Doğuş Kalkanı (Mavi Kalkan)"]="🛡️  Spawn Shield (Blue Forcefield)",
    ["🏃‍♂️  Süper Hız Aktif Et"]="🏃‍♂️  Enable Super Speed",
    ["⚡  Süper Hız Değeri"]="⚡  Super Speed Value",
    ["🚀  Süper Zıplama Gücü"]="🚀  Super Jump Power",
    ["🦘  Sınırsız Zıplama (Infinite Jump)"]="🦘  Infinite Jump",
    ["UÇUŞ MODU (FLY)"]="FLIGHT MODE (FLY)",
    ["🛸  Fly (Uçma) Modu"]="🛸  Fly Mode",
    ["Fly Açma/Kapatma Tuşu"]="Fly Toggle Key", ["🚀  Fly Hızı"]="🚀  Fly Speed",
    ["PERFORMANS VE FPS MODLARI"]="PERFORMANCE AND FPS MODES",
    ["📈  FPS Modu (Optimizasyon)"]="📈  FPS Mode (Optimization)",
    ["⚡  Ultra FPS Modu (Maksimum Performans)"]="⚡  Ultra FPS Mode (Maximum Performance)",
    ["ESP (DUVAR ARKASI GÖRÜŞ)"]="ESP (WALL VISION)",
    ["👁️  ESP (Duvar Arkası Görüş)"]="👁️  ESP (Wall Vision)",
    ["🎨  Çerçeve Rengi"]="🎨  Outline Color", ["🔤  İsim Rengi"]="🔤  Name Color",
    ["🎯  ESP Hedefi"]="🎯  ESP Target",
    ["🎯  Sadece Seçili Oyuncunun ESP'si"]="🎯  ESP Only for Selected Player",
    ["Yeşil"]="Green", ["Kırmızı"]="Red", ["Mavi"]="Blue", ["Sarı"]="Yellow",
    ["Turuncu"]="Orange", ["Mor"]="Purple", ["Pembe"]="Pink", ["Beyaz"]="White", ["RGB"]="RGB",
    ["ESP Hedefi"]="ESP Target", ["Hedefli ESP"]="Target ESP", ["Hedef Yok"]="No Target",
    ["Hedef oyuncu oyundan çıktı."]="Target player left the game.",
    ["Eşleşen oyuncu bulunamadı."]="No matching player found.",
    ["Önce yukarıdan ESP hedefi seçin!"]="Select an ESP target above first!",
    ["Tüm oyuncular tekrar gösteriliyor."]="All players are shown again.",
    ["Sadece seçili oyuncu duvar arkasından görünüyor!"]="Only the selected player is visible through walls!",
    ["Oyuncular duvar arkasından görünüyor!"]="Players are visible through walls!",
    ["HEDEF OYUNCU SEÇİMİ VE ARAMA"]="TARGET PLAYER SELECTION AND SEARCH",
    ["Oyuncu Ara / Seç"]="Find / Select Player",
    ["AKTİF TROLL ÖZELLİKLERİ (12 ADET)"]="ACTIVE TROLL FEATURES (12)",
    ["AKTİF TROLL ÖZELLİKLERİ (11 ADET)"]="ACTIVE TROLL FEATURES (11)",
    ["🔗  1. Seçilen Kişiye Yapış"]="🔗  1. Attach to Selected Player",
    ["📎  1b. Oyuncuyu Kendine Yapıştır"]="📎  1b. Attach Player to You",
    ["💥  3. Oyuncuya Patlama Efekti"]="💥  3. Explosion Effect on Player",
    ["☄️  5. Kafasına Taş/Blok Düşür"]="☄️  5. Drop Rock/Block on Player",
    ["📌  6. Oyuncuyu Olduğu Yere Sabitle"]="📌  6. Freeze Player in Place",
    ["💃  7. Oyuncuyu Sars / Sallantı Ver"]="💃  7. Shake Player",
    ["🕶️  8. Hedefin Bilgilerini Al"]="🕶️  8. Get Target Information",
    ["🔄  9. Kamera Efekti (FOV Trolling)"]="🔄  9. Camera Effect (FOV Troll)",
    ["💨  10. Sunucudaki Herkesi Zıplat"]="💨  10. Make Everyone Jump",
    ["👁️  11. Seçilen Oyuncuyu İzle"]="👁️  11. Spectate Selected Player",
    ["🚀  12. Seçilen Oyuncunun Yanına Işınlan"]="🚀  12. Teleport to Selected Player",
    ["🎣  13. Seçilen Oyuncuyu Yanıma Çek"]="🎣  13. Pull Selected Player to Me",
    ["💥  14. Seçili Oyuncuyu Fırlat (1000x)"]="💥  14. Fling Selected Player (1000x)",
    ["PREMİUM KİLİDİ"]="PREMIUM LOCKED",
    ["🔄  Premium Durumunu Yenile"]="🔄  Refresh Premium Status",
    ["🔑  Premium İste  (Discord Sunucusu)"]="🔑  Request Premium (Discord)",
    ["PREMİUM DURUMU"]="PREMIUM STATUS",
    ["👑  PREMİUM HAREKET"]="👑  PREMIUM MOVEMENT",
    ["👑  PREMİUM GÖRÜNÜM"]="👑  PREMIUM APPEARANCE",
    ["👑  PREMİUM OTO TOPLAYICI"]="👑  PREMIUM AUTO COLLECTOR",
    ["👑  PREMİUM ARAÇLAR"]="👑  PREMIUM TOOLS",
    ["PREMİUM YÖNETİMİ"]="PREMIUM MANAGEMENT",
    ["✅  Premium Ver"]="✅  Grant Premium", ["❌  Premium Kaldır"]="❌  Remove Premium",
    ["📜  Premium Listesini Yükle"]="📜  Load Premium List",
    ["VERİTABANI GİZLİ ANAHTARI  (sadece bu cihazda saklanır)"]="DATABASE SECRET KEY (stored on this device)",
    ["💾  Gizli Anahtarı Kaydet"]="💾  Save Secret Key",
    ["🔒  Yönetimi Kilitle ve Gizle"]="🔒  Lock and Hide Admin",
    ["PREMİUM OLAN HESAPLAR  (tıkla = kaldır)"]="PREMIUM ACCOUNTS (click to remove)",
    ["Menü Tuşu Değiştirildi"]="Menu Key Changed",
    ["Fly Tuşu Değiştirildi"]="Fly Key Changed",
    ["Tuş Bekleniyor"]="Waiting for Key",
    ["Yeni kısayol: "]="New shortcut: ",
    ["Yeni Fly tuşu: "]="New Fly key: ",
    ["Fly Aktif"]="Fly Enabled", ["Uçuş modu açıldı! Tuş: "]="Flight mode enabled! Key: ",
    ["Fly Kapandı"]="Fly Disabled", ["Uçuş modu kapatıldı."]="Flight mode disabled.",
    ["ESP Aktif"]="ESP Enabled", ["ESP Kapandı"]="ESP Disabled",
    ["Oyuncu Seçilmedi"]="No Player Selected",
    ["Önce bir Roblox kullanıcı adı yaz."]="Enter a Roblox username first.",
    ["Kopyalandı"]="Copied", ["Kopyalanamadı"]="Copy Failed",
    ["Discord adresi kopyalandı ✅"]="Discord address copied ✅",
    ["Premium Gerekli"]="Premium Required", ["Hata"]="Error",
    ["Bekle"]="Please Wait", ["Boş"]="Empty", ["Giriş"]="Login", ["İptal"]="Cancel",
    ["Yapımcı:"]="Creator:", ["Hesap yaşı: "]="Account age: ",
    ["EZRAGOX HUB'a hoş geldin!"]="Welcome to EZRAGOX HUB!",
    ["Menüyü G tuşuyla açıp kapatabilirsin. Yapımcı: Hasan Usta"]="Press G to open or close the menu. Creator: Hasan Usta",
    ["PREMIUM ALMAK İÇİN TIKLA  ›"]="CLICK HERE TO GET PREMIUM  ›",
    ["Davet bağlantısı panoya kopyalandı."]="Invite link copied to clipboard.",
    ["Bağlantı:"]="Link:",
    ["Açılıyor... Açılmazsa bağlantı panoya kopyalandı."]="Opening... If it does not open, the link was copied to the clipboard.",
    ["Açık!"]="Enabled!",
    ["Aktif!"]="Active!",
    ["Uygulandı!"]="Applied!",
    ["Görünüm Kuşanıldı 👕"]="Appearance Equipped 👕",
    ["Kuşanılamadı"]="Could Not Equip",
    ["Oto Toplayıcı"]="Auto Collector",
    ["Oto Toplayıcı Kapandı"]="Auto Collector Disabled",
    ["Tarama Bitti"]="Scan Complete",
    ["Para Bulunamadı"]="No Currency Found",
    ["Liste Alınamadı"]="Could Not Load List",
    ["Liste Boş"]="List Is Empty",
    ["Liste Yüklendi"]="List Loaded",
    ["Bağlantı Hatası"]="Connection Error",
    ["Gizli Anahtar Yok"]="Missing Secret Key",
    ["Veritabanı Yok"]="Database Unavailable",
    ["Işınlandın"]="Teleported",
    ["İzleme Aktif"]="Spectating",
    ["İzleme Kapandı"]="Spectating Stopped",
    ["Hedef Bilgisi"]="Target Information",
    ["Kamera Troll"]="Camera Troll",
    ["Toplu Zıplama"]="Mass Jump",
    ["Yanına Çekildi"]="Pulled to You",
    ["Kısmen Çekildi"]="Partially Pulled",
    ["Çekilemedi"]="Could Not Pull",
    ["Sallantı Bitti"]="Shaking Finished",
    ["Blok Düştü"]="Block Dropped",
    ["Sabitlendi"]="Frozen",
    ["Patlama"]="Explosion",
    ["Tıkla-Işınlan"]="Click Teleport",
    ["Gökkuşağı Aura"]="Rainbow Aura",
    ["Uzaklaşma sınırı kaldırıldı."]="Zoom limit removed.",
    ["🎯  Rol ESP (Katil • Polis • Masum • Kahraman • Düşen Silah)"]="🎯  Role ESP (Murderer • Sheriff • Innocent • Hero • Dropped Gun)",
    ["🔪  Atılan Bıçak ESP (Katil Fırlatınca Kırmızı)"]="🔪  Thrown Knife ESP (Red)",
    ["⏱️  Tur Süresi Göstergesi (Ekranda Sürüklenebilir)"]="⏱️  Round Timer (Draggable)",
    ["🧟  Zombi Modu (Zombilere de Ateş Et)"]="🧟  Zombie Mode (Shoot Zombies Too)",
    ["🧱  Duvar Arkası Vuruş  (👑 PREMİUM)"]="🧱  Shoot Through Walls (👑 PREMIUM)",
    ["☠️  Kill Aura  (Yakındakileri Otomatik Öldür)"]="☠️  Kill Aura (Automatically Eliminate Nearby Players)",
    ["🎯  Headshot Sesi (Katile İsabet Edince)"]="🎯  Headshot Sound (When Hitting the Murderer)",
    ["🔔  Silah Düşünce Üstte Bildirim"]="🔔  On-Screen Notification When the Gun Drops",
    ["🔫  Düşen Silaha Otomatik Işınlan"]="🔫  Auto-Teleport to Dropped Gun",
    ["🏃  Katil Yaklaşınca Güvenli Yere Işınlan"]="🏃  Teleport to Safety When the Murderer Approaches",
    ["💰  Oto Coin Farm (Yerin Altında Yatay)"]="💰  Auto Coin Farm (Horizontal Underground)",
    ["⚡  Turbo Süzülme (Işınlanmaya Yakın)"]="⚡  Turbo Glide (Near-Teleport)",
    ["🚀  Turbo Hızı"]="🚀  Turbo Speed",
    ["🕳️  Gizli Odaya Git"]="🕳️  Go to Secret Room",
    ["↩️  Gizli Odadan Çık"]="↩️  Leave Secret Room",
    ["⬇️  Yerin Altı Derinliği"]="⬇️  Underground Depth",
    ["📏  Aura Menzili"]="📏  Aura Range",
    ["🌌  GÖKYÜZÜ SEÇİMİ"]="🌌  SKY SELECTION",
    ["🌌  Gökyüzü Değiştir"]="🌌  Change Sky",
    ["🌠  Gökyüzü 1"]="🌠  Sky 1", ["🌠  Gökyüzü 2"]="🌠  Sky 2",
    ["🌠  Gökyüzü 3"]="🌠  Sky 3", ["🌠  Gökyüzü 4"]="🌠  Sky 4", ["🌠  Gökyüzü 5"]="🌠  Sky 5",
    ["♻️  Gökyüzünü Sıfırla (Varsayılan)"]="♻️  Reset Sky (Default)",
    ["🌌 Gökyüzü yükleniyor..."]="🌌 Loading sky...",
    ["🌌 Gökyüzü varsayılana döndürüldü."]="🌌 Sky reset to default.",
    ["🌌 Gökyüzü uygulanamadı (kod hatası)."]="🌌 Could not apply sky (script error).",
    ["💀  Headless (Kafasız)"]="💀  Headless",
    ["🦴  Korblox (Sağ Bacak)"]="🦴  Korblox (Right Leg)",
    ["🚨  Hileci Tespiti (Kırmızı HİLE Yazısı)"]="🚨  Cheater Detection (Red CHEATER Label)",
    ["🛡️  Anti-AFK (Atılmayı Engelle)"]="🛡️  Anti-AFK (Prevent Being Kicked)",
    ["Premium Gerekli"]="Premium Required",
    ["Önce geçerli bir anahtar gir."]="Enter a valid key first.",
    ["MURDER MYSTERY 2  •  ROL ESP"]="MURDER MYSTERY 2 • ROLE ESP",
    ["KATİL = KIRMIZI  •  POLİS = MAVİ  •  MASUM = YEŞİL  •  KAHRAMAN = SARI  •  DÜŞEN SİLAH = TURUNCU"]="MURDERER = RED • SHERIFF = BLUE • INNOCENT = GREEN • HERO = YELLOW • DROPPED GUN = ORANGE",
    ["TUR SÜRESİ"]="ROUND TIMER", ["KESKİN VURUŞ"]="QUICK SHOT",
    ["ÖLDÜRME  (KATİL: BIÇAK  •  POLİS: SİLAH)"]="ELIMINATION (MURDERER: KNIFE • SHERIFF: GUN)",
    ["☠️  KILL AURA"]="☠️  KILL AURA", ["KILL AURA AYARLARI"]="KILL AURA SETTINGS",
    ["FIRLATMA  (1000x GÜÇ)"]="FLING (1000x POWER)", ["SİLAH SESLERİ  •  OYUN İÇİ SES"]="WEAPON SOUNDS • IN-GAME AUDIO",
    ["DÜŞEN SİLAH"]="DROPPED GUN", ["OTOMATİK KAÇIŞ"]="AUTO ESCAPE",
    ["OTO FARM"]="AUTO FARM", ["IŞINLANMA"]="TELEPORTATION",
    ["👑  PREMİUM HEADLESS & KORBLOX"]="👑  PREMIUM HEADLESS & KORBLOX",
    ["👑  PREMİUM HİLECİ TESPİTİ"]="👑  PREMIUM CHEATER DETECTION",
    ["👑  PREMİUM ARAÇLAR"]="👑  PREMIUM TOOLS",
    ["👑  PREMİUM OTO TOPLAYICI"]="👑  PREMIUM AUTO COLLECTOR",
    ["👑  PREMİUM SAHTE TAG & RGB İSİM"]="👑  PREMIUM FAKE TAG & RGB NAME",
    ["🚀  PREMİUM FPS ARTIRICI"]="🚀  PREMIUM FPS BOOSTER",
    ["👑  PREMİUM HAREKET"]="👑  PREMIUM MOVEMENT",
    ["👑  PREMİUM GÖRÜNÜM"]="👑  PREMIUM APPEARANCE",
    ["PREMİUM KİLİDİ"]="PREMIUM LOCK", ["PREMİUM DURUMU"]="PREMIUM STATUS",
    ["Silah sesi değiştirildi."]="Weapon sound changed.",
    ["Katil bulundu!"]="Murderer found!", ["Polis bulundu!"]="Sheriff found!",
}
local EN_REPLACEMENTS = {
    ["Gökyüzü uygulandı!"] = "Sky applied!",
    ["Gökyüzü yükleniyor"] = "Loading sky",
    ["Görünmezlik"] = "Invisibility",
    ["Katil"] = "Murderer",
    ["Polis"] = "Sheriff",
    ["Masum"] = "Innocent",
    ["Kahraman"] = "Hero",
    ["Düşen Silah"] = "Dropped Gun",
    ["Tur Süresi"] = "Round Time",
    ["Kafasız"] = "Headless",
    ["Sağ Bacak"] = "Right Leg",
    ["Yerin Altında Yatay"] = "Horizontal Underground",
    ["Katil Yaklaşınca"] = "When the Murderer Approaches",
    ["TÜRK TROLL SCRİPTİ"] = "TURKISH TROLL SCRIPT",
    ["BAĞLANDI"] = "CONNECTED",
    ["KULLANICI DOĞRULANDI"] = "USER VERIFIED",
    ["Hazır!"] = "Ready!",
    ["Yapımcı"] = "Creator",
    ["Hoş geldin"] = "Welcome",
    ["hoş geldin"] = "welcome",
    ["Hesap yaşı"] = "Account age",
    ["gün"] = "days",
    ["İsim yaz (örn: hasan)"] = "Enter a name (e.g. Alex)",
    ["Eşleşen oyuncu yok"] = "No matching players",
    ["Server İçinde"] = "In This Server",
    ["Genel Kullanıcı"] = "Global User",
    ["İsmin başını yaz, liste süzülür"] = "Type the start of a name to filter the list",
    ["Roblox kullanıcı adı yaz"] = "Enter a Roblox username",
    ["Şifre"] = "Password",
    ["Devam etmek için yönetim şifresini gir."] = "Enter the admin password to continue.",
    ["YÖNETİM GİRİŞİ"] = "ADMIN LOGIN",
    ["Yönetici erişimi ile açık."] = "Open with administrator access.",
    ["premium tanımlı."] = "premium is enabled.",
    ["Kaydedildi"] = "Saved",
    ["Kaydedilemedi"] = "Could Not Save",
    ["Yönetim Kilitlendi"] = "Admin Locked",
    ["Sekme gizlendi."] = "The tab has been hidden.",
    ["Yönetim Açıldı"] = "Admin Unlocked",
    ["Erişim Engellendi"] = "Access Denied",
    ["Şifre Hatalı"] = "Incorrect Password",
    ["Biraz Bekle"] = "Please Wait",
    ["Çok fazla hatalı deneme. Bir süre sonra tekrar dene."] = "Too many incorrect attempts. Try again later.",
    ["3 hatalı deneme. 30 saniye bekle."] = "3 incorrect attempts. Wait 30 seconds.",
    ["Tekrar dene."] = "Try again.",
    ["Dil Türkçe olarak değiştirildi."] = "Language changed to Turkish.",
    ["DİL / LANGUAGE"] = "LANGUAGE",
    ["Dil / Language"] = "Language",
    ["Türkçe"] = "Turkish",
    ["Uygula"] = "Apply",
    ["Seçilen Oyuncuyu Kopyala"] = "Copy Selected Player",
    ["Karakteri Komple Kopyala"] = "Copy Entire Character",
    ["Saç"] = "Hair",
    ["Üst"] = "Top",
    ["Alt"] = "Bottom",
    ["Aksesuar"] = "Accessories",
    ["Önce bir Roblox kullanıcı adı yaz."] = "Enter a Roblox username first.",
    ["Listeden bir oyuncu seç (ya da adını yaz)."] = "Select a player from the list (or enter their name).",
    ["Bu adda bir Roblox hesabı yok: "] = "No Roblox account exists with this name: ",
    ["Kullanıcı Adı Boş"] = "Username Is Empty",
    ["Kullanıcı Bulunamadı"] = "User Not Found",
    ["Oyuncu Seçilmedi"] = "No Player Selected",
    ["Hedef Seçildi"] = "Target Selected",
    ["Hedef Bilgisi"] = "Target Information",
    ["Hesap"] = "Account",
    ["Durum"] = "Status",
    ["Lütfen önce yukarıdan hedef oyuncu seçin!"] = "Select a target player above first!",
    ["Lütfen önce bir hedef oyuncu seçin!"] = "Select a target player first!",
    ["Hedefin karakteri şu an yok veya ölü."] = "The target's character is missing or dead.",
    ["Önceki işlem hâlâ sürüyor."] = "The previous action is still running.",
    ["Kendi karakterin hazır değil."] = "Your character is not ready.",
    ["Oyuncudan ayrıldınız."] = "You detached from the player.",
    ["Oyuncu serbest bırakıldı."] = "The player has been released.",
    ["Efekt yalnızca senin ekranında görünür."] = "The effect is visible only on your screen.",
    ["Blok yalnızca senin ekranında görünür."] = "The block is visible only on your screen.",
    ["Kamera efektleri uygulandı!"] = "Camera effects applied!",
    ["Sunucudaki herkes zıplatıldı!"] = "Everyone in the server was made to jump!",
    ["Hedef oyuncu oyundan ayrıldı."] = "The target player left the game.",
    ["Kamera kendi karakterine döndü."] = "The camera returned to your character.",
    ["Açılıyor... Açılmazsa bağlantı panoya kopyalandı."] = "Opening... If it does not open, the link was copied to your clipboard.",
    ["Önce geçerli bir anahtar gir."] = "Enter a valid key first.",
    ["Aktif! Duvarların içinden geçebilirsin."] = "Enabled! You can move through walls.",
    ["Ctrl basılıyken bir yere sol tıkla."] = "Hold Ctrl and left-click somewhere.",
    ["Karakterin dönmeye başladı!"] = "Your character has started spinning!",
    ["Normal değere döndü."] = "Returned to the normal value.",
    ["Her yer aydınlandı!"] = "Everything is now illuminated!",
    ["Karakterin renk değiştiriyor!"] = "Your character is changing colors!",
    ["Uzaklaşma sınırı kaldırıldı."] = "The zoom-out limit has been removed.",
    ["görünümü uygulandı."] = " outfit applied.",
    ["bilinmiyor"] = "unknown",
    ["Aktif edildi!"] = "Enabled!",
    ["Kapatıldı."] = "Disabled.",
    ["Görünmez oldun!"] = "You are now invisible!",
    ["Görünür hale geldin."] = "You are visible again.",
    ["Hızın artırıldı!"] = "Your speed has been increased!",
    ["Normale döndü."] = "Returned to normal.",
    ["Zıplama gücü artırıldı!"] = "Your jump power has been increased!",
    ["Uçuş modu açıldı! Tuş: "] = "Flight mode enabled! Key: ",
    ["Uçuş modu kapatıldı."] = "Flight mode disabled.",
    ["FPS Optimizasyonu aktif! Gölgeler ve efektler kapatıldı."] = "FPS optimization enabled! Shadows and effects disabled.",
    ["Normal ayarlara dönüldü."] = "Normal settings restored.",
    ["Ultra FPS Modu aktif! Donanım yükü minimuma indirildi."] = "Ultra FPS mode enabled! Hardware load reduced to a minimum.",
    ["Ultra mod kapatıldı."] = "Ultra mode disabled.",
    ["Oyuncular duvar arkasından yeşil renkte görünüyor!"] = "Players are now visible in green through walls!",
    ["Oyuncu işaretleri kaldırıldı."] = "Player markers removed.",
    ["Sunucu ID panoya kopyalandı."] = "Server ID copied to clipboard.",
    ["Oyun ID panoya kopyalandı."] = "Game ID copied to clipboard.",
    ["Executor panoya yazmayı desteklemiyor."] = "The executor does not support copying to the clipboard.",
    ["Aynı sunucuya yeniden bağlanılıyor..."] = "Reconnecting to the same server...",
    ["Aktif! Boşta kalsan da atılmazsın."] = "Enabled! You will not be kicked for being idle.",
    ["En yakın paradan başlayıp tek tek toplanacak."] = "Collecting one by one, starting with the nearest item.",
    ["Şu an eşleşen yok. Yeni spawn olanlar otomatik alınır. İstersen 'Özel İsim' yaz."] = "No matches right now. Newly spawned items will be collected automatically. You can enter a custom name.",
    [" parça toplandı."] = " items collected.",
    ["Hiç bulunamadı. 'Özel İsim' kutusuna paranın adını yaz (örn: Coin)."] = "Nothing found. Enter the item name in the 'Custom Name' box (e.g. Coin).",
    ["Önce veritabanı gizli anahtarını kaydet."] = "Save the database secret key first.",
    ["Veritabanı adresini kontrol et."] = "Check the database URL.",
    ["Henüz premium verilen hesap yok."] = "No accounts have been granted premium yet.",
    [" hesap bulundu."] = " accounts found.",
    ["Gizli anahtarı yapıştır."] = "Paste the secret key.",
    ["Gizli anahtar bu cihaza kaydedildi."] = "The secret key was saved on this device.",
    ["Executor dosya yazmayı desteklemiyor."] = "The executor does not support file writing.",
    ["Premium sunucusuna ulaşılamadı. Tekrar dene."] = "Could not reach the premium server. Try again.",
    ["Hesabın için premium tanımlı, hoş geldin!"] = "Premium is enabled for your account. Welcome!",
    [" hesabında premium tanımlı değil."] = " does not have premium enabled.",
    ["Veritabanına yazılamadı. Adres ve gizli anahtarı kontrol et."] = "Could not write to the database. Check the URL and secret key.",
    ["Listeden elle sil: PREMIUM_NAMES."] = "Remove it manually from the list: PREMIUM_NAMES.",
    ["Satır panoya kopyalandı: dosyadaki PREMIUM_NAMES listesine ekle."] = "The line was copied to the clipboard: add it to the PREMIUM_NAMES list in the file.",
    ["Veritabanından silinemedi."] = "Could not delete from the database.",
    ["Menü için yeni bir klavye tuşuna basın..."] = "Press a new key for the menu...",
    ["Menüyü küçült"] = "Minimize Menu",
    ["Arayüzü tamamen kapat"] = "Close Interface",
    ["İsim"] = "Name",
    ["Ara"] = "Search",
    ["Seç"] = "Select",
    ["Oyuncu"] = "Player",
    ["Aktif"] = "Enabled",
    ["Hedef"] = "Target",
    ["Kullanıcı"] = "User",
    ["Bağlantı Hatası"] = "Connection Error",
    ["Premium Yok"] = "No Premium",
    ["Premium Aktif"] = "Premium Enabled",
    ["Premium Gerekli"] = "Premium Required",
    ["Liste Yüklendi"] = "List Loaded",
    ["Liste Boş"] = "List Is Empty",
    ["Liste Alınamadı"] = "Could Not Load List",
    ["Tarama Bitti"] = "Scan Complete",
    ["Para Bulunamadı"] = "Item Not Found",
    ["Oto Toplayıcı"] = "Auto Collector",
    ["Oto Toplayıcı Kapandı"] = "Auto Collector Disabled",
    ["Anti-AFK"] = "Anti-AFK",
    ["Tıkla-Işınlan"] = "Click to Teleport",
    ["Yerçekimi"] = "Gravity",
    ["Gökkuşağı Aura"] = "Rainbow Aura",
    ["Görünüm Kuşanıldı"] = "Outfit Equipped",
    ["Kuşanılamadı"] = "Could Not Equip",
    ["Veritabanı Yok"] = "Database Unavailable",
    ["Gizli Anahtar Yok"] = "Secret Key Missing",
    ["Premium Verildi"] = "Premium Granted",
    ["Premium Kaldırıldı"] = "Premium Removed",
    ["Yeni kısayol: "] = "New shortcut: ",
    ["Yeni Fly tuşu: "] = "New Fly key: ",
    ["menüyü aç / kapat"] = "toggle menu",
    ["Fling Başarılı"] = "Fling Successful",
    ["Fling Etkisiz"] = "Fling Ineffective",
    ["Havaya Uçuruldu"] = "Launched into the Air",
    ["Sky Etkisiz"] = "Sky Launch Ineffective",
    ["Uzaya Fırlatıldı"] = "Launched into Space",
    ["Etkisiz"] = "Ineffective",
    ["Yanına Çekildi"] = "Pulled to You",
    ["Kısmen Çekildi"] = "Partially Pulled",
    ["Çekilemedi"] = "Could Not Pull",
    ["Sallantı Bitti"] = "Shaking Finished",
    ["Patlama"] = "Explosion",
    ["Blok Düştü"] = "Block Dropped",
    ["Sabitlendi"] = "Frozen",
    ["Toplu Zıplama"] = "Mass Jump",
    ["İzleme Aktif"] = "Spectating Enabled",
    ["İzleme Kapandı"] = "Spectating Disabled",
    ["Işınlandın"] = "Teleported",
    ["Yapışma Aktif"] = "Attachment Enabled",
    ["Yapışma Kapandı"] = "Attachment Disabled",
    ["Yapıştırma Aktif"] = "Player Attachment Enabled",
    ["Yapıştırma Kapandı"] = "Player Attachment Disabled",
    ["Zaten Yakın"] = "Already Nearby",
    ["Fly Aktif"] = "Fly Enabled",
    ["Fly Kapandı"] = "Fly Disabled",
    ["ESP Aktif"] = "ESP Enabled",
    ["ESP Kapandı"] = "ESP Disabled",
    ["Menü Tuşu Değiştirildi"] = "Menu Key Changed",
    ["Fly Tuşu Değiştirildi"] = "Fly Key Changed",
    ["Tuş Bekleniyor"] = "Waiting for Key",
    ["Süper Hız"] = "Super Speed",
    ["Süper Zıplama"] = "Super Jump",
    ["Sınırsız Zıplama"] = "Infinite Jump",
    ["Hayalet Modu"] = "Ghost Mode",
    ["Doğuş Kalkanı"] = "Spawn Shield",
    ["Mavi kalkanın içindesin!"] = "You are inside the blue shield!",
    ["Kalkan kaldırıldı."] = "Shield removed.",
    ["FPS Modu"] = "FPS Mode",
    ["Ultra FPS"] = "Ultra FPS",
    ["Hedef oyuncu"] = "Target player",
    ["Hedefin"] = "Target's",
    ["İzleniyor"] = "Being Spectated",
    ["Discord Sunucusu"] = "Discord Server",
    ["Yönetim şifresi"] = "Admin password",
    ["Menü Tuşu"] = "Menu Key",
    ["Bulanık arka plan"] = "Blurred Background",
    ["Menü boyutu"] = "Menu Size",
    ["Ses efektleri"] = "Sound Effects",
    ["Görünüm"] = "Appearance",
    ["Karakter"] = "Character",
    ["Özellikler"] = "Features",
    ["Ana Sayfa"] = "Home",
    ["Ayarlar"] = "Settings",
    ["Yönetim"] = "Admin",
    ["Premium Durumunu Yenile"] = "Refresh Premium Status",
    ["Premium İste"] = "Request Premium",
    ["Premium Ver"] = "Grant Premium",
    ["Premium Kaldır"] = "Remove Premium",
    ["Premium Listesini Yükle"] = "Load Premium List",
    ["Gizli Anahtarı Kaydet"] = "Save Secret Key",
    ["Yönetimi Kilitle ve Gizle"] = "Lock and Hide Admin",
    ["PREMİUM OLAN HESAPLAR"] = "PREMIUM ACCOUNTS",
    ["VERİTABANI GİZLİ ANAHTARI"] = "DATABASE SECRET KEY",
    ["Sadece bu cihazda saklanır"] = "Stored on this device only",
    ["Yapımcı:"] = "Creator:",
    ["KONTROL"] = "CONTROLS",
    ["DİĞER"] = "OTHER",
    ["👑  EZRAGOX PREMİUM"] = "👑  EZRAGOX PREMIUM",
    ["Noclip • Tıkla-Işınlan • Fullbright • Gökkuşağı Aura • Dönen Karakter • Yerçekimi • FOV • Zoom Kilidi • Gün Saati • Anti-AFK • Rejoin ve daha fazlası. Premium, Roblox hesabına özel tanımlanır."] = "Noclip • Click Teleport • Fullbright • Rainbow Aura • Spin Character • Gravity • FOV • Zoom Lock • Time of Day • Anti-AFK • Rejoin and more. Premium is assigned to your Roblox account.",
    ["👤  Hesabın: "] = "👤  Your Account: ",
    ["Bu hesapta premium tanımlı değil. Premium istemek için Discord sunucusuna gel."] = "Premium is not enabled for this account. Join the Discord server to request Premium.",
    ["PREMİUM AKTİF"] = "PREMIUM ACTIVE",
    ["Hesap: "] = "Account: ",
    ["  •  premium tanımlı."] = "  •  Premium enabled.",
    ["Yönetici erişimi ile açık."] = "Enabled with administrator access.",
    ["👻  Noclip (Duvarlardan Geç)"] = "👻  Noclip (Walk Through Walls)",
    ["🖱️  Tıkla-Işınlan  (Ctrl + Sol Tık)"] = "🖱️  Click Teleport (Ctrl + Left Click)",
    ["🌀  Dönen Karakter (Spin)"] = "🌀  Spin Character",
    ["🌪️  Dönme Hızı"] = "🌪️  Spin Speed",
    ["🪐  Yerçekimi"] = "🪐  Gravity",
    ["♻️  Yerçekimini Normale Döndür"] = "♻️  Reset Gravity",
    ["💡  Fullbright (Her Yer Aydınlık)"] = "💡  Fullbright (Brighten Everything)",
    ["🌈  Gökkuşağı Aura"] = "🌈  Rainbow Aura",
    ["🔭  Görüş Açısı (FOV)"] = "🔭  Field of View (FOV)",
    ["🔍  Kamera Zoom Sınırını Kaldır"] = "🔍  Remove Camera Zoom Limit",
    ["🌙  Gün Saati"] = "🌙  Time of Day",
    ["🌍  Genel Kullanıcı"] = "🌍  Global User",
    ["🖥️  Server İçinde"] = "🖥️  In This Server",
    ["Genel Kullanıcı"] = "Global User",
    ["Roblox kullanıcı adı yaz"] = "Enter Roblox username",
    ["👑  PREMİUM OTO TOPLAYICI"] = "👑  PREMIUM AUTO COLLECTOR",
    ["Özel İsim"] = "Custom Name",
    ["örn: Coin, Gold  (boş = otomatik bul)"] = "e.g. Coin, Gold (blank = auto-detect)",
    ["👑  PREMİUM ARAÇLAR"] = "👑  PREMIUM TOOLS",
    ["👑  PREMİUM HİLECİ TESPİTİ"] = "👑  PREMIUM CHEATER DETECTION",
    ["👑  PREMİUM HEADLESS & KORBLOX"] = "👑  PREMIUM HEADLESS & KORBLOX",
    ["💀  Headless & Korblox"] = "💀  Headless & Korblox",
    ["Headless: yalnızca gerçek karakter kafan ve yüzü görünmez olur; saç, şapka ve baş aksesuarların yerinde kalır. Korblox: sağ bacak silinir. Yalnızca senin ekranında görünür, diğer oyuncular görmez. Yeniden doğunca otomatik uygulanır; kapatınca eski görünüm geri gelir."] = "Headless: only your actual character head and face become invisible; hair, hats, and head accessories stay. Korblox: the right leg is removed. Only visible on your screen, other players cannot see it. Re-applied on respawn; turning it off restores your original look.",
    ["Aktif! Sağ bacağın silindi."] = "Active! Your right leg is removed.",
    ["🧱  Duvar Arkası Vuruş  (👑 PREMİUM)"] = "🧱  Wallbang Shot  (👑 PREMIUM)",
    ["Duvar arkası vuruş sadece premium kullanıcılar içindir."] = "Wallbang shot is for premium users only.",
    ["Duvar Arkası Vuruş"] = "Wallbang Shot",
    ["Aktif! Ateş edince mermi duvarlardan geçip katile gider."] = "Active! When you shoot, the bullet goes through walls to the murderer.",
    ["Aktif! (Executor atış hook'unu desteklemiyor: tıklayınca katile ayrıca ateş edilir.)"] = "Active! (Your executor does not support the shot hook: clicking also fires at the murderer.)",
    ["💀  Headless (Kafasız)"] = "💀  Headless",
    ["🦴  Korblox (Sağ Bacak)"] = "🦴  Korblox (Right Leg)",
    ["Aktif! Kafan ve yüzün görünmez oldu."] = "Active! Your head and face are hidden.",
    ["Aktif! Sağ bacağın Korblox oldu."] = "Active! Your right leg is now Korblox.",
    ["Executor bacak mesh'ini değiştirmeyi desteklemiyor; sağ bacak gizlendi."] = "Your executor does not support changing leg meshes; the right leg was hidden instead.",
    ["Korblox bacağı yüklenemedi (executor desteklemiyor olabilir); sağ bacak gizlendi."] = "Could not load the Korblox leg (your executor may not support it); the right leg was hidden instead.",
    ["Korblox bacağı yükleniyor..."] = "Loading the Korblox leg...",
    ["🚨  Hileci Tespiti"] = "🚨  Cheater Detection",
    ["🚨  Hileci Tespiti (Kırmızı HİLE Yazısı)"] = "🚨  Cheater Detection (Red CHEAT Tag)",
    ["Fly, hız, noclip, spin ve yerin altına girme gibi diğer oyuncuların ekranında görünen hileleri algılar; hile yapan oyuncunun üstüne kırmızı HİLE yazar. ESP gibi sadece kişinin kendi ekranında çalışan hileler dışarıdan görülemez."] = "Detects cheats that are visible to other players such as fly, speed, noclip, spin and going under the map, and writes a red CHEAT tag above the offender. Client-only cheats such as ESP cannot be detected from the outside.",
    ["Hileci Tespiti"] = "Cheater Detection",
    ["Aktif! Hile yapan oyuncunun üstünde kırmızı HİLE yazar."] = "Active! A red CHEAT tag appears above players who are cheating.",
    ["Hile Tespit Edildi"] = "Cheat Detected",
    ["👑  PREMİUM HAREKET"] = "👑  PREMIUM MOVEMENT",
    ["👑  PREMİUM GÖRÜNÜM"] = "👑  PREMIUM APPEARANCE",
    ["PREMİUM KİLİDİ"] = "PREMIUM LOCK",
    ["PREMİUM DURUMU"] = "PREMIUM STATUS",
    ["PREMİUM YÖNETİMİ"] = "PREMIUM MANAGEMENT",
    ["PREMİUM OLAN HESAPLAR  (tıkla = kaldır)"] = "PREMIUM ACCOUNTS (click to remove)",
    ["🛡️  Sadece sana özel"] = "🛡️  Admin Only",
    ["Premium vermek istediğin kişinin Roblox kullanıcı adını yaz. Premium o hesaba tanımlanır; kişi menüyü açınca kendi hesabıyla otomatik premium olur."] = "Enter the Roblox username of the person you want to grant Premium to. Premium will be assigned to that account and activated automatically when they open the menu.",
    ["Kullanıcı"] = "User",
    ["Roblox kullanıcı adı (örn: hasanusta_03)"] = "Roblox username (e.g. player123)",
    ["Gizli Anahtar"] = "Secret Key",
    ["Firebase veritabanı gizli anahtarı"] = "Firebase database secret key",
    ["VERİTABANI GİZLİ ANAHTARI  (sadece bu cihazda saklanır)"] = "DATABASE SECRET KEY (stored on this device only)",
    ["Sadece bu cihazda saklanır"] = "Stored on this device only",
    ["👤  "] = "👤  ",
    ["Kendi Görünümüme Dön"] = "Return to My Outfit",
    ["Görünümünü Kuşan"] = "Equip Outfit",
    ["Oyuncuyu Ara"] = "Search Player",
    ["Oyuncu Bul"] = "Find Player",
    ["Kıyafet"] = "Outfit",
    ["Karakter Görünümü"] = "Character Appearance",
    ["Oyuncu Listesi"] = "Player List",
    ["Hız"] = "Speed",
    ["Gün Saati"] = "Time of Day",
    ["Yerçekimini Normale Döndür"] = "Reset Gravity",
    ["Aktif! Duvarların içinden geçebilirsin."] = "Enabled! You can walk through walls.",
    ["Ctrl basılıyken bir yere sol tıkla."] = "Hold Ctrl and left-click anywhere.",
    ["Karakterin dönmeye başladı!"] = "Your character has started spinning!",
    ["Her yer aydınlandı!"] = "Everything is now illuminated!",
    ["Karakterin renk değiştiriyor!"] = "Your character is changing colors!",
    ["Uzaklaşma sınırı kaldırıldı."] = "The zoom limit has been removed.",
    ["Normal değere döndü."] = "Returned to normal.",
    ["Bu hesapta premium tanımlı değil."] = "Premium is not enabled for this account.",
    ["Premium istemek için Discord sunucusuna gel."] = "Join the Discord server to request Premium.",
    ["Önce geçerli bir anahtar gir."] = "Enter a valid key first.",
    ["Hesabın için premium tanımlı, hoş geldin!"] = "Premium is enabled for your account. Welcome!",
    [" hesabında premium tanımlı değil."] = " does not have Premium enabled.",
    ["Premium sunucusuna ulaşılamadı. Tekrar dene."] = "Could not reach the Premium server. Try again.",
    ["Henüz premium verilen hesap yok."] = "No accounts have been granted Premium yet.",
    [" hesap bulundu."] = " accounts found.",
    ["Premium verildi"] = "Premium granted",
    ["Premium kaldırıldı"] = "Premium revoked",
    ["premiumu kaldır"] = "revoke Premium",
    ["panoya kopyalandı"] = "copied to clipboard",
    ["panoya kopyalandı."] = "copied to clipboard.",
    ["Önce"] = "First",
    ["önce"] = "first",
    ["Lütfen"] = "Please",
    ["seçin"] = "select",
    ["seçin."] = "select.",
    ["açıldı"] = "enabled",
    ["kapatıldı"] = "disabled",
    ["başladı"] = "started",
    ["bitti"] = "finished",
    ["bulundu"] = "found",
    ["bulunamadı"] = "not found",
    ["kaydedildi"] = "saved",
    ["kaydedilemedi"] = "could not be saved",
    ["kopyalandı"] = "copied",
    ["kopyalanamadı"] = "could not be copied",
    ["hesap bulundu"] = "accounts found",
    ["hesap bulundu."] = "accounts found.",
    ["tuşu ile"] = "with the key",
    ["tuşuna bas"] = "press the key",

}
local function trText(value)
    if type(value) ~= "string" or Settings.Language ~= "EN" then return value end
    if EN_TEXT[value] then return EN_TEXT[value] end
    local cached = UI_TEXT_OBJECTS.trc[value]
    if cached then return cached end
    local keys = UI_TEXT_OBJECTS.sk
    if not keys then
        keys = {}
        for source in pairs(EN_REPLACEMENTS) do keys[#keys + 1] = source end
        table.sort(keys, function(a, b) return #a > #b end)
        UI_TEXT_OBJECTS.sk = keys
    end
    local result = value
    for _, source in ipairs(keys) do
        if string.find(result, source, 1, true) then
            local pattern = source:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
            result = string.gsub(result, pattern, function() return EN_REPLACEMENTS[source] end)
        end
    end
    if UI_TEXT_OBJECTS.trn > 4000 then UI_TEXT_OBJECTS.trc, UI_TEXT_OBJECTS.trn = {}, 0 end
    UI_TEXT_OBJECTS.trc[value] = result
    UI_TEXT_OBJECTS.trn = UI_TEXT_OBJECTS.trn + 1
    return result
end

local function setLocalizedProperty(obj, property, value)
    if not obj then return end
    local idx = UI_TEXT_OBJECTS.idx
    local per = idx[obj]
    if not per then per = {} idx[obj] = per end
    local entry = per[property]
    if entry then
        entry.original = value
    else
        entry = {obj = obj, original = value, property = property}
        per[property] = entry
        UI_TEXT_OBJECTS[#UI_TEXT_OBJECTS + 1] = entry
    end
    local tr = trText(value)
    pcall(function()
        if obj[property] ~= tr then obj[property] = tr end
    end)
end

local function setText(obj, value)
    setLocalizedProperty(obj, "Text", value)
end

local function setPlaceholder(obj, value)
    setLocalizedProperty(obj, "PlaceholderText", value)
end

local function applyLanguage()
    for i = #UI_TEXT_OBJECTS, 1, -1 do
        local entry = UI_TEXT_OBJECTS[i]
        local obj = entry.obj
        if obj and obj.Parent then
            pcall(function()
                if entry.property == "PlaceholderText" then
                    obj.PlaceholderText = trText(entry.original)
                else
                    obj.Text = trText(entry.original)
                end
            end)
        else
            table.remove(UI_TEXT_OBJECTS, i)
            if obj then UI_TEXT_OBJECTS.idx[obj] = nil end
        end
    end
end

local function new(class, props, parent)
    local o = Instance.new(class)
    for k, v in pairs(props) do
        if (k == "Text" or k == "PlaceholderText") and type(v) == "string" then
            local entry = {obj = o, original = v, property = k}
            UI_TEXT_OBJECTS[#UI_TEXT_OBJECTS + 1] = entry
            local per = UI_TEXT_OBJECTS.idx[o]
            if not per then per = {} UI_TEXT_OBJECTS.idx[o] = per end
            per[k] = entry
            o[k] = trText(v)
        else
            o[k] = v
        end
    end
    if parent then o.Parent = parent end
    return o
end
local function corner(o, r)
    return new("UICorner", {CornerRadius = UDim.new(0, r)}, o)
end
local function pill(o)
    return new("UICorner", {CornerRadius = UDim.new(1, 0)}, o)
end
local function stroke(o, th, col, tr)
    return new("UIStroke", {Thickness = th, Color = col or Color3.new(1, 1, 1), Transparency = tr or 0}, o)
end
local function tween(obj, time, props, style, dir)
    local t = TweenService:Create(obj, TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
    t:Play()
    return t
end

local function playSound(pitch, volume)
    if not Settings.Sound then return end
    pcall(function()
        local s = Instance.new("Sound")
        s.SoundId = "rbxassetid://4590657391"
        s.Volume = volume or 1
        s.Pitch = pitch or 1.2
        s.Parent = SoundService
        s:Play()
        task.delay(1.5, function() s:Destroy() end)
    end)
end
local playClickSound
do
    local lastClickSoundAt = 0
    function playClickSound()
        local now = os.clock()
        if now - lastClickSoundAt < 0.06 then return end
        lastClickSoundAt = now
        playSound(1.18, 0.42)
    end
end

local PALETTE = {
    Color3.fromRGB(255, 28, 48),
    Color3.fromRGB(150, 8, 24),
    Color3.fromRGB(255, 72, 38),
    Color3.fromRGB(70, 5, 14),
}
local function palette(x)
    local n = #PALETTE
    x = x % n
    local i = math.floor(x)
    local f = x - i
    f = f * f * (3 - 2 * f)
    return PALETTE[i + 1]:Lerp(PALETTE[(i + 1) % n + 1], f)
end
local function accentAt(off)
    return palette(os.clock() * 0.7 + (off or 0))
end

local function flowSeq(phase, step)
    local t = os.clock() * 0.7 + (phase or 0)
    step = step or 0.5
    local pts = {}
    for k = 0, 4 do
        pts[k + 1] = ColorSequenceKeypoint.new(k / 4, palette(t - k * step))
    end
    return ColorSequence.new(pts)
end

local NOTIF_PALETTE = {
    Color3.fromRGB(255, 30, 50),
    Color3.fromRGB(120, 6, 18),
    Color3.fromRGB(60, 4, 10),
    Color3.fromRGB(200, 14, 34),
}
local function notifPalette(x)
    local n = #NOTIF_PALETTE
    x = x % n
    local i = math.floor(x)
    local f = x - i
    f = f * f * (3 - 2 * f)
    return NOTIF_PALETTE[i + 1]:Lerp(NOTIF_PALETTE[(i + 1) % n + 1], f)
end
local function notifFlowSeq(phase, step)
    local t = os.clock() * 0.7 + (phase or 0)
    step = step or 0.5
    local pts = {}
    for k = 0, 4 do
        pts[k + 1] = ColorSequenceKeypoint.new(k / 4, notifPalette(t - k * step))
    end
    return ColorSequence.new(pts)
end
local UIFlows, UIAccents, Pulsers, Shines = {}, {}, {}, {}
local IntroFlows, IntroAccents = {}, {}
local function regFlow(list, grad, phase, step, spin)
    phase, step = phase or 0, step or 0.5
    -- key: ayni phase/step'e sahip tum gradientler her karede AYNI ColorSequence'i paylasir
    list[#list + 1] = {grad = grad, phase = phase, step = step, spin = spin, key = tostring(phase) .. "|" .. tostring(step)}
    grad.Color = flowSeq(phase, step)
end
local function track(list, obj, prop, off)
    list[#list + 1] = {obj = obj, prop = prop, off = off or 0}
end

local function typeText(lbl, txt, delay)
    setText(lbl, txt)
    lbl.MaxVisibleGraphemes = 0
    local n = utf8.len(txt) or #txt
    for i = 1, n do
        lbl.MaxVisibleGraphemes = i
        task.wait(delay)
    end
    lbl.MaxVisibleGraphemes = -1
end

local function getScale(baseW, baseH, lo)
    local cam = workspace.CurrentCamera or workspace:FindFirstChildOfClass("Camera")
    if not cam then return 1 end
    local vp = cam.ViewportSize
    if vp.X <= 0 or vp.Y <= 0 then return 1 end
    return math.clamp(math.min(vp.Y / baseH, vp.X / baseW), lo or 0.5, 1)
end

local function makeShine(parent, z)
    local shine = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(-0.6, 0, 0.5, 0),
        Size = UDim2.new(0.35, 0, 2, 0),
        Rotation = 20,
        BackgroundColor3 = Color3.new(1, 1, 1),
        BackgroundTransparency = 0.45,
        BorderSizePixel = 0,
        ZIndex = z,
    }, parent)
    new("UIGradient", {Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(0.5, 0),
        NumberSequenceKeypoint.new(1, 1),
    })}, shine)
    return shine
end
local function playShine(shine, dur)
    shine.Position = UDim2.new(-0.6, 0, 0.5, 0)
    tween(shine, dur or 0.7, {Position = UDim2.new(1.6, 0, 0.5, 0)}, Enum.EasingStyle.Quad)
end

local blurEffect = new("BlurEffect", {Name = "EZRAGOX_Blur", Size = 0, Enabled = true}, Lighting)
local cc = new("ColorCorrectionEffect", {Name = "EZRAGOX_CC", Saturation = -1, Contrast = 0.15, Brightness = 0}, Lighting)

local ScreenGui = new("ScreenGui", {
    Name = GUI_NAME,
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    DisplayOrder = 999,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
do
    local ok = pcall(function()
        if gethui then
            ScreenGui.Parent = gethui()
        else
            ScreenGui.Parent = CoreGui
        end
    end)
    if not ok or not ScreenGui.Parent then
        ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end
end

---------------------------------------------------------
-- 1. SİNEMATİK GİRİŞ  (kırmızı-siyah EZRAGOX HUB girişi)
-- Not: Tüm giriş kodu kendi fonksiyonunun içinde çalışır; ana bölümdeki
-- "local" sayısı 200 sınırının altında kalır. Dışarıya yalnızca Intro.play(onPeak) açılır.
---------------------------------------------------------
local Intro = (function()
    local I = {}

    local AYAR = {
        SES             = true,                      -- giriş sesleri
        SES_SEVIYESI    = 1,                         -- 0 - 2 arası ana ses çarpanı
        SES_ID          = "rbxassetid://4590657391", -- tüm efektler bu sesin farklı pitch'leri
        KAMERA_EFEKTI   = true,                      -- FOV zoom + hafif kamera sarsıntısı
        EKRAN_TITREMESI = true,                      -- darbe anlarında arayüz sarsıntısı
        ATLA_BUTONU     = true,                      -- SPACE / ENTER / buton ile atla
        KOD_YAGMURU     = true,                      -- arka plan matrix yağmuru
        NEON_IZGARA     = true,                      -- perspektif neon zemin
        HUD_BILGILERI   = true,                      -- boot terminali + FPS / PING / saat
        PARLAK_FLASLAR  = true,                      -- false = beyaz flaşlar daha sönük (ışığa duyarlı olanlar için)
    }

    -- Ekran boyutuna göre giriş ölçeği (küçük ekranlarda sığsın)
    local function introScale()
        local cam = workspace.CurrentCamera
        if not cam then return 1 end
        local vp = cam.ViewportSize
        return math.clamp(math.min(vp.Y / 800, vp.X / 620), 0.5, 1)
    end
    local UI_SCALE = 1
    local bloom
    local MarketplaceService = game:GetService("MarketplaceService")

    local function playSound(pitch, volume, life)
        if not AYAR.SES then return end
        pcall(function()
            local sound = Instance.new("Sound")
            sound.SoundId = AYAR.SES_ID
            sound.Volume = math.clamp((volume or 1) * AYAR.SES_SEVIYESI, 0, 10)
            local p = pitch or 1.2
            if not pcall(function() sound.PlaybackSpeed = p end) then
                pcall(function() sound.Pitch = p end)
            end
            sound.Parent = SoundService
            sound:Play()
            task.delay(life or 1.5, function() sound:Destroy() end)
        end)
    end

    -- Yükselen "riser" sesi: aynı ses döngüde, hızı giderek artar
    local function startRiser(duration, fromPitch, toPitch, volume)
        if not AYAR.SES then return end
        pcall(function()
            local s = Instance.new("Sound")
            s.SoundId = AYAR.SES_ID
            s.Looped = true
            s.Volume = 0
            s.PlaybackSpeed = fromPitch
            s.Parent = SoundService
            s:Play()
            tween(s, duration, {PlaybackSpeed = toPitch, Volume = volume * AYAR.SES_SEVIYESI}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
            task.delay(duration, function()
                pcall(function() s:Stop() s:Destroy() end)
            end)
        end)
    end

    local ACCENT = Color3.fromRGB(225, 15, 25)   -- ana kan kırmızısı
    local WHITE = Color3.fromRGB(255, 225, 225)
    local GREEN = Color3.fromRGB(255, 70, 70)    -- "onay" rengi (artık parlak kırmızı)
    local BG = Color3.fromRGB(7, 0, 1)


    -- Kırmızı <-> siyah nabız: yavaş kalp atışı + hızlı titreme
    local function kanAt(offset)
        local t = tick()
        local w = math.sin(t * 2.2 + offset) * 0.5 + 0.5
        local f = (math.sin(t * 11 + offset * 3) * 0.5 + 0.5) * 0.14
        local k = math.clamp(w * 0.86 + f, 0, 1)
        return Color3.fromRGB(48, 0, 4):Lerp(Color3.fromRGB(255, 25, 35), k)
    end

    local FLASH_MIN = AYAR.PARLAK_FLASLAR and 0 or 0.7 -- flaşın en parlak hali

    local LOGO_TEXT = "EZRAGOX"
    local SUB_TEXT = "TÜRK TROLL SCRİPTİ"
    local LN = #LOGO_TEXT
    local LETTER_W, LETTER_GAP = 60, 4
    local LOGO_W = LN * (LETTER_W + LETTER_GAP) - LETTER_GAP
    local CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789#@$%&?"
    local RAIN_CHARS = "0123456789ABCDEFXZRAGOK#$%@?+=*"

    -- Logo katmanları: kırmızı hayalet, mavi hayalet, ana harf (kromatik sapma)
    local LAYERS = {
        {off = -3, trans = 0.5, color = Color3.fromRGB(255, 0, 30), z = 1},
        {off = 3, trans = 0.15, color = Color3.fromRGB(18, 0, 0), z = 2},
        {off = 0, trans = 0, color = ACCENT, z = 3},
    }

    local STATUSES = {
        {0, "Çekirdek başlatılıyor"},
        {12, "Modüller yükleniyor"},
        {28, "Arayüz hazırlanıyor"},
        {44, "Efektler ayarlanıyor"},
        {60, "Karakter doğrulanıyor"},
        {76, "Troll araçları senkronize ediliyor"},
        {90, "Son kontroller yapılıyor"},
        {99, "Hazır!"},
    }

    -- {saniye, yüzde}: bilerek duraksamalı (gerçek yükleme hissi)
    local PROG_KEYS = {{0, 0}, {0.4, 12}, {0.8, 20}, {1.4, 44}, {1.65, 48}, {2.3, 74}, {2.55, 79}, {3.2, 100}}

    -- {saniye, etiket, mesaj}: boot terminali
    local BOOT_LINES = {
        {0.40, ">", "EZRAGOX//ÇEKİRDEK başlatılıyor"},
        {0.85, "OK", "sistem saati senkronize edildi"},
        {1.25, "OK", "ağ bağlantısı kuruldu"},
        {1.65, "OK", "oyuncu profili bulundu: " .. LocalPlayer.Name},
        {2.05, "OK", "render motoru bağlandı"},
        {2.50, "OK", "efekt modülleri yüklendi"},
        {2.95, "OK", "arayüz çerçevesi hazır"},
        {3.40, "!!", "erişim anahtarı doğrulanıyor..."},
        {4.10, "OK", "karakter verisi eşleşti"},
        {4.80, "OK", "troll araçları senkronize"},
        {5.60, "OK", "erişim onaylandı"},
    }

    local UI = {} -- giriş elemanları
    local ST = {  -- giriş durumu
        skipped = false, done = false,
        shake = 0, shaking = false,
        flash = {}, conns = {},
        rainLevel = 0, rainTarget = 0, rainTick = 0,
        gridLevel = 0, gridTarget = 0, gridPhase = 0, GH = 0.58,
        tickN = 0, lastRainTr = 1,
        hudLevel = 0, hudTarget = 0,
        frames = 0, fpsAcc = 0, fps = 60, ping = 0, pingAcc = 1,
        log = {}, blink = true,
        gameName = nil, barGreen = false, lastMsg = "",
        origFOV = 70, compact = false,
        vp = Vector2.new(1280, 720),
        t0 = os.clock(),
    }
    for i = 1, LN do ST.flash[i] = 0 end

    ---------------------------------------------------------
    -- Küçük kurucu yardımcılar
    ---------------------------------------------------------
    local function mk(class, props, parent)
        local o = Instance.new(class)
        if props then
            for k, v in pairs(props) do o[k] = v end
        end
        if parent then o.Parent = parent end
        return o
    end

    local function mkFrame(props, parent)
        props.BorderSizePixel = 0
        if props.BackgroundTransparency == nil then props.BackgroundTransparency = 1 end
        return mk("Frame", props, parent)
    end

    local function mkLabel(props, parent)
        props.BorderSizePixel = 0
        props.BackgroundTransparency = 1
        if props.Text == nil then props.Text = "" end
        return mk("TextLabel", props, parent)
    end

    local function mkCircle(props, parent)
        local f = mkFrame(props, parent)
        mk("UICorner", {CornerRadius = UDim.new(1, 0)}, f)
        return f
    end

    local function mkStroke(obj, thickness, color, transparency)
        return mk("UIStroke", {Thickness = thickness, Color = color or ACCENT, Transparency = transparency or 0}, obj)
    end

    local function mkGrad(obj, props)
        return mk("UIGradient", props, obj)
    end

    -- seq(t1, v1, t2, v2, ...) -> NumberSequence
    local function seq(...)
        local a, kp = {...}, {}
        for i = 1, #a, 2 do
            kp[#kp + 1] = NumberSequenceKeypoint.new(a[i], a[i + 1])
        end
        return NumberSequence.new(kp)
    end

    local function randChar()
        local n = math.random(1, #CHARS)
        return CHARS:sub(n, n)
    end

    local function rainRefresh(col)
        local t = {}
        for i = 1, col.rows - 1 do
            local n = math.random(1, #RAIN_CHARS)
            t[i] = RAIN_CHARS:sub(n, n)
        end
        local n = math.random(1, #RAIN_CHARS)
        t[col.rows] = '<font color="#FF9A9A">' .. RAIN_CHARS:sub(n, n) .. "</font>"
        col.lbl.Text = table.concat(t, "\n")
    end

    -- "TÜRK" -> "T Ü R K" (geniş harf aralığı, sinematik görünüm)
    local function spaced(s)
        local out = {}
        for _, cp in utf8.codes(s) do
            out[#out + 1] = utf8.char(cp)
        end
        return table.concat(out, " ")
    end

    -- RichText için güvenli metin
    local function esc(s)
        return (tostring(s):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
    end

    local function clip(s, n)
        if (utf8.len(s) or #s) > n then
            local off = utf8.offset(s, n + 1)
            if off then return s:sub(1, off - 1) .. "..." end
        end
        return s
    end

    ---------------------------------------------------------
    -- Zaman / sarsıntı / kamera
    ---------------------------------------------------------
    -- Atlanınca anında döner
    local function sleep(t)
        local waited = 0
        while waited < t and not ST.skipped do
            local step = math.min(0.05, t - waited)
            task.wait(step)
            waited = waited + step
        end
    end

    local function addShake(p)
        if AYAR.EKRAN_TITREMESI and p > ST.shake then ST.shake = p end
    end

    local function camSet(fov)
        if not AYAR.KAMERA_EFEKTI then return end
        pcall(function()
            local cam = workspace.CurrentCamera
            if cam then cam.FieldOfView = fov end
        end)
    end

    local function camTween(time, fov, style, dir)
        if not AYAR.KAMERA_EFEKTI then return end
        pcall(function()
            local cam = workspace.CurrentCamera
            if cam then tween(cam, time, {FieldOfView = fov}, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out) end
        end)
    end

    local function setCamOffset(x, y)
        if not (AYAR.KAMERA_EFEKTI and ST.hum) then return end
        pcall(function() ST.hum.CameraOffset = ST.camOff0 + Vector3.new(x, y, 0) end)
    end

    -- Atlama destekli daktilo
    local function typeX(lbl, txt, delay)
        lbl.Text = txt
        lbl.MaxVisibleGraphemes = 0
        local n = utf8.len(txt) or #txt
        for i = 1, n do
            if ST.skipped then break end
            lbl.MaxVisibleGraphemes = i
            task.wait(delay)
        end
        lbl.MaxVisibleGraphemes = -1
    end

    -- Rastgele karakterlerden çözülerek gerçek metne dönüşür (ASCII metinler için)
    local function scrambleText(lbl, final, dur)
        task.spawn(function()
            local t0 = os.clock()
            local n = #final
            while os.clock() - t0 < dur do
                local p = (os.clock() - t0) / dur
                local out = {}
                for i = 1, n do
                    if i / n <= p then out[i] = final:sub(i, i) else out[i] = randChar() end
                end
                lbl.Text = table.concat(out)
                task.wait(0.03)
            end
            lbl.Text = final
        end)
    end

    ---------------------------------------------------------
    -- Efekt fonksiyonları
    ---------------------------------------------------------
    local function shockwave(thickness, color, target, time)
        local r = mkCircle({
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0, 0, 0, 0),
            Size = UDim2.new(0, 10, 0, 10),
            ZIndex = 5,
        }, UI.stage)
        local s = mkStroke(r, thickness, color, 0)
        tween(r, time, {Size = UDim2.new(0, target, 0, target)}, Enum.EasingStyle.Quint)
        tween(s, time, {Thickness = 0.5, Transparency = 1})
        task.delay(time + 0.05, function() r:Destroy() end)
    end

    local function burstRays(color, len)
        local off = math.random(0, 14)
        for i, r in ipairs(UI.rays) do
            r.Rotation = (i - 1) * 15 + off
            r.Size = UDim2.new(0, 3, 0, 0)
            r.BackgroundColor3 = color
            r.BackgroundTransparency = 0.15
            tween(r, 0.75, {Size = UDim2.new(0, 1, 0, len or 2400), BackgroundTransparency = 1}, Enum.EasingStyle.Quint)
        end
    end

    -- Glitch "dilimleri": logonun yanında anlık yatay çizgiler
    local function glitchSlices(n)
        for _ = 1, n do
            local x = math.random(-180, 180)
            local y = -12 + math.random(-40, 40)
            local s = mkFrame({
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(0, x, 0, y),
                Size = UDim2.new(0, math.random(80, 320), 0, math.random(3, 9)),
                BackgroundColor3 = (math.random() < 0.5) and ACCENT or Color3.fromRGB(255, 0, 40),
                BackgroundTransparency = 0.2,
                ZIndex = 14,
            }, UI.stage)
            tween(s, 0.14, {Position = UDim2.new(0, x + math.random(-40, 40), 0, y), BackgroundTransparency = 1}, Enum.EasingStyle.Linear)
            task.delay(0.16, function() s:Destroy() end)
        end
    end

    local function setLetter(i, ch)
        for li = 1, 3 do UI.layers[li][i].Text = ch end
        UI.shineLabel[i].Text = ch
    end

    local function setAberr(a, b)
        for i = 1, LN do
            UI.layers[1][i].Position = UDim2.new(0, -a, 0, 0)
            UI.layers[2][i].Position = UDim2.new(0, b, 0, 0)
        end
    end

    -- Harf yere çakıldığında: titreme + ışık çizgisi + halka + ses
    local function letterImpact(i)
        addShake(5)
        playSound(0.85 + i * 0.09, 0.55)
        local cx = UI.letterBase[i] - LOGO_W / 2
        local s = mkFrame({
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0, cx, 0, -12),
            Size = UDim2.new(0, 5, 0, 150),
            BackgroundColor3 = WHITE, BackgroundTransparency = 0.05, ZIndex = 14,
        }, UI.stage)
        tween(s, 0.4, {Size = UDim2.new(0, 36, 0, 300), BackgroundTransparency = 1}, Enum.EasingStyle.Quint)
        local r = mkCircle({
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0, cx, 0, -12),
            Size = UDim2.new(0, 10, 0, 10), ZIndex = 14,
        }, UI.stage)
        local rs = mkStroke(r, 3, ACCENT, 0)
        tween(r, 0.45, {Size = UDim2.new(0, 130, 0, 130)}, Enum.EasingStyle.Quint)
        tween(rs, 0.45, {Transparency = 1, Thickness = 0.5})
        task.delay(0.5, function()
            s:Destroy()
            r:Destroy()
        end)
    end

    -- Harf büyük ölçekten çakılır, rastgele karakterlerden çözülür
    local function slamLetter(i)
        local sc = UI.letterScale[i]
        sc.Scale = 3.4
        for li = 1, 3 do UI.layers[li][i].TextTransparency = 1 end
        for li = 1, 3 do tween(UI.layers[li][i], 0.14, {TextTransparency = LAYERS[li].trans}) end
        tween(sc, 0.24, {Scale = 1}, Enum.EasingStyle.Quart, Enum.EasingDirection.In)

        local lock = 0.32 + 0.045 * i
        local t0 = os.clock()
        local impacted = false
        while not ST.skipped do
            local el = os.clock() - t0
            if not impacted and el >= 0.24 then
                impacted = true
                letterImpact(i)
            end
            if el >= lock then break end
            setLetter(i, randChar())
            task.wait(0.035)
        end
        if not impacted then letterImpact(i) end
        setLetter(i, LOGO_TEXT:sub(i, i))
        ST.flash[i] = 1
    end

    -- Logo üzerinde soldan sağa beyaz parıltı geçer
    local function sweepShine(i)
        local lbl, g = UI.shineLabel[i], UI.shineGrad[i]
        g.Offset = Vector2.new(-1, 0)
        lbl.Visible = true
        tween(g, 0.55, {Offset = Vector2.new(1, 0)}, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
        task.delay(0.6, function() lbl.Visible = false end)
    end

    local function glitchBurst(n, power)
        for _ = 1, n do
            if ST.skipped then break end
            UI.logoHolder.Position = UDim2.new(0, UI.logoX + math.random(-power, power), 0, -12 + math.random(-3, 3))
            setAberr(math.random(3, 13), math.random(3, 13))
            for i = 1, LN do
                UI.layers[3][i].TextTransparency = (math.random() < 0.25) and 0.6 or 0
            end
            if math.random() < 0.5 then glitchSlices(1) end
            task.wait(0.035)
        end
        UI.logoHolder.Position = UDim2.new(0, UI.logoX, 0, -12)
        setAberr(3, 3)
        for i = 1, LN do UI.layers[3][i].TextTransparency = 0 end
    end

    -- Durum değişimlerinde kısa, hafif glitch
    local function microGlitch()
        if ST.skipped then return end
        setAberr(math.random(6, 11), math.random(6, 11))
        glitchSlices(1)
        task.wait(0.06)
        setAberr(3, 3)
    end

    -- Merkezden saçılan kıvılcımlar
    local function burstSparks(n, maxDist, color)
        for _ = 1, n do
            local ang = math.random() * math.pi * 2
            local dist = maxDist * (0.35 + math.random() * 0.65)
            local sz = math.random(3, 6)
            local p = mkFrame({
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(0, 0, 0, -12),
                Size = UDim2.new(0, sz, 0, sz),
                Rotation = math.random(0, 90),
                BackgroundColor3 = (math.random() < 0.4) and WHITE or (color or ACCENT),
                BackgroundTransparency = 0,
                ZIndex = 14,
            }, UI.stage)
            local dur = 0.55 + math.random() * 0.6
            tween(p, dur, {
                Position = UDim2.new(0, math.cos(ang) * dist, 0, -12 + math.sin(ang) * dist),
                Size = UDim2.new(0, 1, 0, 1),
                BackgroundTransparency = 1,
            }, Enum.EasingStyle.Quad)
            task.delay(dur + 0.05, function() p:Destroy() end)
        end
    end

    -- Enerji toplanması: kenarlardan merkeze doğru akan ışık çizgileri
    local function spawnConverge()
        local ang = math.random() * math.pi * 2
        local dist = ST.vp.Y * (0.55 + math.random() * 0.5)
        local dx, dy = math.cos(ang) * dist * 1.4, math.sin(ang) * dist
        local p = mkFrame({
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, dx, 0.4, dy),
            Size = UDim2.new(0, 2, 0, math.random(14, 34)),
            Rotation = math.deg(math.atan2(dx, -dy)),
            BackgroundColor3 = (math.random() < 0.2) and WHITE or ACCENT,
            BackgroundTransparency = 0.15,
            ZIndex = 1,
        }, UI.particles)
        local dur = 0.65 + math.random() * 0.5
        tween(p, dur, {
            Position = UDim2.new(0.5, 0, 0.4, 0),
            Size = UDim2.new(0, 2, 0, 3),
            BackgroundTransparency = 0.9,
        }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        task.delay(dur + 0.05, function() p:Destroy() end)
    end

    ---------------------------------------------------------
    -- HUD yazıları (terminal, FPS/PING, oyun bilgisi)
    ---------------------------------------------------------
    local function refreshTerm()
        if not UI.term then return end
        UI.term.Text = table.concat(ST.log, "\n") .. "\n" .. '<font color="#FF2030">' .. (ST.blink and "_" or " ") .. "</font>"
    end

    local function pushLog(tag, msg)
        local prefix
        if tag == "OK" then
            prefix = '<font color="#FF5A5A">[ OK ]</font> '
        elseif tag == "!!" then
            prefix = '<font color="#FFB0B0">[ !! ]</font> '
        else
            prefix = '<font color="#FF2030">&gt;</font> '
        end
        ST.log[#ST.log + 1] = prefix .. msg
        if #ST.log > 8 then table.remove(ST.log, 1) end
        refreshTerm()
    end

    local function startBootLog()
        if not UI.term then return end
        task.spawn(function()
            local t0 = os.clock()
            for _, ln in ipairs(BOOT_LINES) do
                while os.clock() - t0 < ln[1] do
                    if ST.skipped or ST.done then return end
                    task.wait(0.03)
                end
                pushLog(ln[2], ln[3])
            end
        end)
    end

    local function updateStats()
        if not UI.stats then return end
        UI.stats.Text = string.format(
            'FPS  <font color="#FF2030">%d</font>\nPING <font color="#FF2030">%d</font> ms\n<font color="#8A5A5E">%s</font>',
            ST.fps, ST.ping, os.date("%H:%M:%S"))
    end

    local function pollPing()
        pcall(function()
            local v = Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
            ST.ping = math.floor(v + 0.5)
        end)
    end

    local function refreshInfo()
        if not (UI.info and UI.info.Parent) then return end
        local name = ST.gameName or "yükleniyor..."
        local job = game.JobId
        if not job or job == "" then job = "yerel" else job = job:sub(1, 8) end
        UI.info.Text = '<font color="#8A5A5E">OYUN</font>    ' .. name .. '\n<font color="#8A5A5E">SUNUCU</font>  ' .. esc(job)
    end

    ---------------------------------------------------------
    -- Kurucular
    ---------------------------------------------------------
    local function buildBackdrop()
        local vp = ST.vp
        -- Giriş, ana ScreenGui içinde en üst katmanda bir Frame'dir (closeAll ile birlikte temizlenir)
        local gui = mkFrame({
            Name = "Giris", Size = UDim2.new(1, 0, 1, 0),
            ClipsDescendants = true, ZIndex = 300,
        }, ScreenGui)
        UI.holder = gui
        UI.gui = gui

        UI.dim = mkFrame({
            Name = "Karartma", Size = UDim2.new(1, 0, 1, 0),
            BackgroundColor3 = BG, BackgroundTransparency = 0.12, ZIndex = 1,
        }, gui)

        UI.world = mkFrame({Name = "Dunya", Size = UDim2.new(1, 0, 1, 0), ZIndex = 2}, gui)

        -- Kod yağmuru -------------------------------------------------
        UI.rain = {}
        UI.rainLayer = mkFrame({Name = "Yagmur", Size = UDim2.new(1, 0, 1, 0), ZIndex = 1}, UI.world)
        if AYAR.KOD_YAGMURU then
            local cols = ST.compact and 14 or 30
            local vh = math.floor(vp.Y)
            for i = 1, cols do
                local rows = math.random(9, 18)
                local lbl = mkLabel({
                    Name = "Sutun" .. i,
                    AnchorPoint = Vector2.new(0.5, 0),
                    Position = UDim2.new((i - 0.5) / cols, 0, 0, -500),
                    Size = UDim2.new(0, 16, 0, rows * 15),
                    Font = Enum.Font.Code, TextSize = 14,
                    TextColor3 = ACCENT, TextTransparency = 1,
                    RichText = true,
                    TextYAlignment = Enum.TextYAlignment.Top,
                }, UI.rainLayer)
                mkGrad(lbl, {Rotation = 90, Transparency = seq(0, 1, 0.7, 0.65, 1, 0)})
                local col = {lbl = lbl, x = (i - 0.5) / cols, y = math.random(-vh, vh), speed = math.random(110, 300), rows = rows}
                rainRefresh(col)
                UI.rain[i] = col
            end
        end

        -- Perspektif neon ızgara --------------------------------------
        UI.gridH, UI.gridV = {}, {}
        UI.gridLayer = mkFrame({Name = "Izgara", Size = UDim2.new(1, 0, 1, 0), ZIndex = 2}, UI.world)
        if AYAR.NEON_IZGARA then
            local GH = ST.GH
            UI.gridGlow = mkFrame({
                AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, GH, 0),
                Size = UDim2.new(1, 0, 0.18, 0), BackgroundColor3 = ACCENT, BackgroundTransparency = 1, ZIndex = 1,
            }, UI.gridLayer)
            mkGrad(UI.gridGlow, {Rotation = 90, Transparency = seq(0, 1, 1, 0.72)})
            UI.gridHorizon = mkFrame({
                AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, GH, 0),
                Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = ACCENT, BackgroundTransparency = 1, ZIndex = 3,
            }, UI.gridLayer)
            mkGrad(UI.gridHorizon, {Transparency = seq(0, 1, 0.15, 0.4, 0.5, 0, 0.85, 0.4, 1, 1)})
            for k = 1, 12 do
                UI.gridH[k] = mkFrame({
                    AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 1, 0),
                    Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = ACCENT, BackgroundTransparency = 1, ZIndex = 2,
                }, UI.gridLayer)
            end
            -- Dikey çizgiler ufuk noktasından alt kenara yelpaze gibi açılır
            local M = 18
            local vx, vy = vp.X * 0.5, vp.Y * GH
            local spread = vp.X * 2.0
            for i = 0, M do
                local dx = (i / M - 0.5) * spread
                local dy = vp.Y - vy
                local len = math.sqrt(dx * dx + dy * dy)
                local ln = mkFrame({
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    Position = UDim2.new(0, vx + dx / 2, 0, vy + dy / 2),
                    Size = UDim2.new(0, 1, 0, len),
                    Rotation = -math.deg(math.atan2(dx, dy)),
                    BackgroundColor3 = ACCENT, BackgroundTransparency = 1, ZIndex = 2,
                }, UI.gridLayer)
                mkGrad(ln, {Rotation = 90, Transparency = seq(0, 1, 1, 0.15)})
                UI.gridV[#UI.gridV + 1] = ln
            end
        end

        -- CRT tarama çizgisi + bandı ----------------------------------
        UI.scan = mkFrame({
            Name = "Tarama", Size = UDim2.new(1, 0, 0, 2),
            BackgroundColor3 = ACCENT, BackgroundTransparency = 0.8, ZIndex = 3,
        }, UI.world)
        local band = mkFrame({
            AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 0, 0),
            Size = UDim2.new(1, 0, 0, 90), BackgroundColor3 = ACCENT, BackgroundTransparency = 0,
        }, UI.scan)
        mkGrad(band, {Rotation = 90, Transparency = seq(0, 1, 1, 0.9)})

        UI.hud = mkFrame({Name = "HUD", Size = UDim2.new(1, 0, 1, 0), ZIndex = 4}, UI.world)

        -- Vinyet (kenarlar kararır, dikkat merkeze toplanır) ----------
        UI.vignette = {}
        local function vg(props, rot)
            props.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
            props.BackgroundTransparency = 1
            props.ZIndex = 3
            local f = mkFrame(props, gui)
            mkGrad(f, {Rotation = rot, Transparency = seq(0, 0.3, 1, 1)})
            UI.vignette[#UI.vignette + 1] = f
        end
        vg({Position = UDim2.new(0, 0, 0, 0), Size = UDim2.new(0.24, 0, 1, 0)}, 0)
        vg({AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0.24, 0, 1, 0)}, 180)
        vg({Position = UDim2.new(0, 0, 0, 0), Size = UDim2.new(1, 0, 0.26, 0)}, 90)
        vg({AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0.26, 0)}, 270)
    end

    local function buildBars()
        local function makeBar(isTop)
            local bar = mkFrame({
                AnchorPoint = Vector2.new(0, isTop and 0 or 1),
                Position = UDim2.new(0, 0, isTop and 0 or 1, 0),
                Size = UDim2.new(1, 0, 0, 0),
                BackgroundColor3 = Color3.fromRGB(0, 0, 0), BackgroundTransparency = 0, ZIndex = 4,
            }, UI.gui)
            local edge = mkFrame({
                AnchorPoint = Vector2.new(0, isTop and 1 or 0),
                Position = UDim2.new(0, 0, isTop and 1 or 0, 0),
                Size = UDim2.new(1, 0, 0, 2),
                BackgroundColor3 = ACCENT, BackgroundTransparency = 0, ZIndex = 1,
            }, bar)
            return bar, edge
        end
        UI.barTop, UI.barTopEdge = makeBar(true)
        UI.barBottom, UI.barBottomEdge = makeBar(false)
    end

    local function buildStage()
        local stage = mkFrame({
            Name = "Sahne", AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, 0, 0.4, 0), Size = UDim2.new(0, 0, 0, 0), ZIndex = 5,
        }, UI.world)
        mk("UIScale", {Scale = UI_SCALE}, stage)
        UI.stage = stage

        UI.particles = mkFrame({Name = "Parcaciklar", Size = UDim2.new(1, 0, 1, 0), ZIndex = 6}, UI.world)

        -- Çekirdek parlaması
        UI.halo = mkCircle({
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0, 0), Size = UDim2.new(0, 0, 0, 0),
            BackgroundColor3 = ACCENT, BackgroundTransparency = 0.85, ZIndex = 1,
        }, stage)
        UI.core = mkCircle({
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0, 0), Size = UDim2.new(0, 0, 0, 0),
            BackgroundColor3 = WHITE, BackgroundTransparency = 0, ZIndex = 2,
        }, stage)

        -- Dönen yay çemberler
        UI.rings = {}
        local specs = {{4, 220, 340}, {2.5, -320, 260}, {1.5, 480, 190}}
        for idx, sp in ipairs(specs) do
            local ring = mkFrame({
                AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0, 0),
                Size = UDim2.new(0, 0, 0, 0), ZIndex = 3,
            }, stage)
            mk("UICorner", {CornerRadius = UDim.new(1, 0)}, ring)
            local stroke = mkStroke(ring, sp[1], ACCENT, 0)
            local grad = mk("UIGradient", {Transparency = seq(0, 0, 0.45, 0.1, 0.5, 1, 1, 1)}, stroke)
            UI.rings[idx] = {frame = ring, stroke = stroke, grad = grad, speed = sp[2], size = sp[3], rot = 0}
        end

        -- Işın patlaması (merkezden çıkan 12 çift yönlü ışın)
        UI.rays = {}
        for i = 0, 11 do
            UI.rays[i + 1] = mkFrame({
                AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0, 0),
                Size = UDim2.new(0, 3, 0, 0), Rotation = i * 15, ZIndex = 4,
            }, stage)
        end

        -- HUD köşe parantezleri
        UI.brackets = mkFrame({
            Name = "Parantez", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0, 12),
            Size = UDim2.new(0, 1000, 0, 520), ZIndex = 6,
        }, stage)
        UI.bracketParts = {}
        for _, c in ipairs({{0, 0}, {1, 0}, {0, 1}, {1, 1}}) do
            for _, d in ipairs({{34, 3}, {3, 34}}) do
                UI.bracketParts[#UI.bracketParts + 1] = mkFrame({
                    AnchorPoint = Vector2.new(c[1], c[2]), Position = UDim2.new(c[1], 0, c[2], 0),
                    Size = UDim2.new(0, d[1], 0, d[2]), BackgroundColor3 = ACCENT, BackgroundTransparency = 1,
                }, UI.brackets)
            end
        end

        -- Logo: her harf ayrı kutu (UIScale ile çakılır) + 3 katman + parıltı
        local holder = mkFrame({
            Name = "Logo", AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0, 0, 0, -12), Size = UDim2.new(0, LOGO_W, 0, 90), ZIndex = 7,
        }, stage)
        UI.logoHolder = holder
        UI.letterBox, UI.letterScale, UI.letterBase = {}, {}, {}
        UI.layers = {{}, {}, {}}
        UI.shineLabel, UI.shineGrad = {}, {}
        for i = 1, LN do
            local baseX = (i - 1) * (LETTER_W + LETTER_GAP) + LETTER_W / 2
            local box = mkFrame({
                Name = "Harf" .. i, AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(0, baseX, 0.5, 0), Size = UDim2.new(0, LETTER_W, 1, 0), ZIndex = 1,
            }, holder)
            UI.letterBox[i] = box
            UI.letterBase[i] = baseX
            UI.letterScale[i] = mk("UIScale", {Scale = 3.4}, box)
            for li, L in ipairs(LAYERS) do
                UI.layers[li][i] = mkLabel({
                    Size = UDim2.new(1, 0, 1, 0), Position = UDim2.new(0, L.off, 0, 0),
                    Font = Enum.Font.GothamBlack, TextSize = 72, TextColor3 = L.color,
                    TextTransparency = 1, Text = randChar(), ZIndex = L.z,
                }, box)
            end
            local sh = mkLabel({
                Size = UDim2.new(1, 0, 1, 0),
                Font = Enum.Font.GothamBlack, TextSize = 72, TextColor3 = WHITE,
                TextTransparency = 0, Text = LOGO_TEXT:sub(i, i), Visible = false, ZIndex = 4,
            }, box)
            UI.shineLabel[i] = sh
            UI.shineGrad[i] = mkGrad(sh, {
                Rotation = 25, Offset = Vector2.new(-1, 0),
                Transparency = seq(0, 1, 0.38, 1, 0.5, 0, 0.62, 1, 1, 1),
            })
        end

        -- "HUB" yazısı: EZRAGOX tamamlanınca sağ yanına çakılır
        local HUB_TEXT = "HUB"
        local HUB_GAP = 28
        local HUB_W = #HUB_TEXT * (LETTER_W + LETTER_GAP) - LETTER_GAP
        UI.hubText, UI.hubW, UI.hubGap = HUB_TEXT, HUB_W, HUB_GAP
        UI.logoX = 0
        UI.hubX = LOGO_W / 2 + HUB_GAP + HUB_W / 2 -- logo kayınca ortalı kalacak şekilde ayarlanır
        local hubHolder = mkFrame({
            Name = "HubYazi", AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0, UI.hubX, 0, -12), Size = UDim2.new(0, HUB_W, 0, 90), ZIndex = 7,
        }, stage)
        UI.hubHolder = hubHolder
        UI.hubBox, UI.hubScale, UI.hubLayers = {}, {}, {{}, {}, {}}
        for i = 1, #HUB_TEXT do
            local baseX = (i - 1) * (LETTER_W + LETTER_GAP) + LETTER_W / 2
            local box = mkFrame({
                Name = "HubHarf" .. i, AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(0, baseX, 0.5, 0), Size = UDim2.new(0, LETTER_W, 1, 0), ZIndex = 1,
            }, hubHolder)
            UI.hubBox[i] = box
            UI.hubScale[i] = mk("UIScale", {Scale = 3.4}, box)
            for li, L in ipairs(LAYERS) do
                UI.hubLayers[li][i] = mkLabel({
                    Size = UDim2.new(1, 0, 1, 0), Position = UDim2.new(0, L.off, 0, 0),
                    Font = Enum.Font.GothamBlack, TextSize = 72, TextColor3 = L.color,
                    TextTransparency = 1, Text = HUB_TEXT:sub(i, i), ZIndex = L.z,
                }, box)
            end
        end

        -- Logo altı çizgi
        UI.line = mkFrame({
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0, 52),
            Size = UDim2.new(0, 0, 0, 2), BackgroundColor3 = ACCENT, BackgroundTransparency = 0, ZIndex = 8,
        }, stage)
        mkGrad(UI.line, {Transparency = seq(0, 0.9, 0.2, 0, 0.8, 0, 1, 0.9)})

        -- Alt başlık (geniş harf aralıklı)
        UI.sub = mkLabel({
            AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.new(0, 560, 0, 24),
            Position = UDim2.new(0, 0, 0, 76), Text = spaced(trText(SUB_TEXT)),
            TextColor3 = Color3.fromRGB(215, 150, 150), TextSize = 15, Font = Enum.Font.GothamBold,
            MaxVisibleGraphemes = 0, ZIndex = 9,
        }, stage)

        -- Yükleme çubuğu + kıvılcım başlığı + durum yazısı
        UI.barBG = mkFrame({
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0, 122),
            Size = UDim2.new(0, 340, 0, 7), BackgroundColor3 = Color3.fromRGB(38, 6, 8),
            BackgroundTransparency = 1, ZIndex = 10,
        }, stage)
        mk("UICorner", {CornerRadius = UDim.new(1, 0)}, UI.barBG)
        UI.barStroke = mkStroke(UI.barBG, 1, ACCENT, 1)
        UI.barFill = mkFrame({
            Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = ACCENT, BackgroundTransparency = 1, ZIndex = 1,
        }, UI.barBG)
        mk("UICorner", {CornerRadius = UDim.new(1, 0)}, UI.barFill)
        UI.spark = mkCircle({
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
            Size = UDim2.new(0, 14, 0, 14), BackgroundColor3 = WHITE, BackgroundTransparency = 1, ZIndex = 2,
        }, UI.barFill)

        UI.status = mkLabel({
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0, 144),
            Size = UDim2.new(0, 380, 0, 20), TextColor3 = Color3.fromRGB(185, 120, 125),
            TextSize = 13, Font = Enum.Font.GothamMedium, TextTransparency = 1, ZIndex = 11,
        }, stage)

        -- Parıltı (lens flare) + "ERİŞİM ONAYLANDI" mührü
        UI.flare = mkFrame({
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0, -12),
            Size = UDim2.new(0, 0, 0, 4), BackgroundColor3 = Color3.fromRGB(255, 195, 195),
            BackgroundTransparency = 1, ZIndex = 12,
        }, stage)
        mkGrad(UI.flare, {Transparency = seq(0, 1, 0.5, 0, 1, 1)})

        UI.stamp = mkLabel({
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0, 188),
            Size = UDim2.new(0, 440, 0, 30), Text = trText("[ ERİŞİM ONAYLANDI ]"),
            TextColor3 = GREEN, TextSize = 22, Font = Enum.Font.GothamBlack, TextTransparency = 1, ZIndex = 13,
        }, stage)
        UI.stampScale = mk("UIScale", {Scale = 1}, UI.stamp)
    end

    local function buildHud()
        if not AYAR.HUD_BILGILERI or ST.compact then return end
        local sc = math.max(UI_SCALE, 0.75)

        UI.term = mkLabel({
            Name = "Terminal", Position = UDim2.new(0, 18, 0.1, 14), Size = UDim2.new(0, 440, 0, 160),
            Font = Enum.Font.Code, TextSize = 13, TextColor3 = Color3.fromRGB(255, 90, 90),
            TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
            RichText = true, TextTransparency = 1, ZIndex = 1,
        }, UI.hud)
        mk("UIScale", {Scale = sc}, UI.term)

        UI.stats = mkLabel({
            Name = "Istatistik", AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -18, 0.1, 14), Size = UDim2.new(0, 220, 0, 52),
            Font = Enum.Font.Code, TextSize = 13, TextColor3 = Color3.fromRGB(195, 130, 135),
            TextXAlignment = Enum.TextXAlignment.Right, TextYAlignment = Enum.TextYAlignment.Top,
            RichText = true, TextTransparency = 1, ZIndex = 1,
        }, UI.hud)
        mk("UIScale", {Scale = sc}, UI.stats)

        UI.info = mkLabel({
            Name = "Bilgi", AnchorPoint = Vector2.new(0, 1),
            Position = UDim2.new(0, 18, 0.9, -12), Size = UDim2.new(0, 340, 0, 34),
            Font = Enum.Font.Code, TextSize = 13, TextColor3 = Color3.fromRGB(195, 130, 135),
            TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Bottom,
            RichText = true, TextTransparency = 1, ZIndex = 1,
        }, UI.hud)
        mk("UIScale", {Scale = sc}, UI.info)
    end

    local function buildCard()
        local card = mkFrame({
            Name = "Kart", AnchorPoint = Vector2.new(0.5, 1),
            Position = UDim2.new(0.5, 0, 1.5, 0), Size = UDim2.new(0, 420, 0, 100),
            BackgroundColor3 = Color3.fromRGB(14, 3, 4), BackgroundTransparency = 0.2, ZIndex = 7,
        }, UI.world)
        UI.card = card
        mk("UICorner", {CornerRadius = UDim.new(0, 16)}, card)
        mk("UIScale", {Scale = math.max(UI_SCALE, 0.7)}, card)
        UI.cardStroke = mkStroke(card, 2, ACCENT, 0)

        local av = mkFrame({
            Name = "Avatar", Position = UDim2.new(0, 14, 0, 10), Size = UDim2.new(0, 80, 0, 80),
            BackgroundColor3 = Color3.fromRGB(32, 8, 10), BackgroundTransparency = 0,
            ClipsDescendants = true, ZIndex = 1,
        }, card)
        mk("UICorner", {CornerRadius = UDim.new(1, 0)}, av)
        UI.avatarStroke = mkStroke(av, 2.5, ACCENT, 0)

        UI.thumb = mk("ImageLabel", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 2}, av)
        local vpf = mk("ViewportFrame", {
            Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0,
            Ambient = Color3.fromRGB(190, 190, 190), LightColor = Color3.fromRGB(255, 255, 255), ZIndex = 3,
        }, av)
        -- Avatar üstünde gezen tarama çizgisi
        UI.avScan = mkFrame({
            Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = ACCENT, BackgroundTransparency = 0.35, ZIndex = 4,
        }, av)

        UI.welcome = mkLabel({
            Position = UDim2.new(0, 108, 0, 14), Size = UDim2.new(1, -125, 0, 16),
            TextColor3 = Color3.fromRGB(185, 120, 125), TextSize = 12, Font = Enum.Font.GothamBold,
            TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 1,
        }, card)
        UI.nameLabel = mkLabel({
            Position = UDim2.new(0, 108, 0, 32), Size = UDim2.new(1, -125, 0, 34),
            TextColor3 = WHITE, TextSize = 26, Font = Enum.Font.GothamBlack,
            TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 1,
        }, card)
        UI.handle = mkLabel({
            Position = UDim2.new(0, 108, 0, 68), Size = UDim2.new(1, -125, 0, 16),
            Text = "@" .. LocalPlayer.Name, TextColor3 = Color3.fromRGB(160, 105, 110),
            TextSize = 12, Font = Enum.Font.GothamMedium, TextXAlignment = Enum.TextXAlignment.Left,
            TextTransparency = 1, ZIndex = 1,
        }, card)
        UI.pill = mkLabel({
            Position = UDim2.new(1, -96, 0, 10), Size = UDim2.new(0, 84, 0, 16),
            Text = "● BAĞLANDI", TextColor3 = Color3.fromRGB(255, 60, 60), TextSize = 10,
            Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Right,
            TextTransparency = 1, ZIndex = 1,
        }, card)

        -- Avatar thumbnail (yedek)
        task.spawn(function()
            for _, thumbType in ipairs({Enum.ThumbnailType.AvatarBust, Enum.ThumbnailType.HeadShot}) do
                local ok, content = pcall(function()
                    return Players:GetUserThumbnailAsync(LocalPlayer.UserId, thumbType, Enum.ThumbnailSize.Size150x150)
                end)
                if ok and content and content ~= "" then
                    UI.thumb.Image = content
                    return
                end
            end
        end)

        -- Oyuncunun gerçek karakterini 3D göster (olmazsa thumbnail kalır)
        pcall(function()
            local char = LocalPlayer.Character
            if not char then return end
            local wasArch = char.Archivable
            char.Archivable = true
            local clone = char:Clone()
            char.Archivable = wasArch
            if not clone then return end

            for _, d in ipairs(clone:GetDescendants()) do
                if d:IsA("LuaSourceContainer") then d:Destroy() end
            end

            local hrp = clone:FindFirstChild("HumanoidRootPart")
            local head = clone:FindFirstChild("Head")
            if not (hrp and head) then clone:Destroy() return end

            clone.Parent = vpf
            local cam = Instance.new("Camera")
            cam.FieldOfView = 30
            local target = head.Position - Vector3.new(0, 0.7, 0)
            local camPos = head.Position + hrp.CFrame.LookVector * 7 + Vector3.new(0, 0.3, 0)
            cam.CFrame = CFrame.lookAt(camPos, target)
            cam.Parent = vpf
            vpf.CurrentCamera = cam

            ST.vpModel = clone
            ST.vpBase = clone:GetPivot()
            UI.thumb.Visible = false
        end)
    end

    local function buildOverlays()
        local gui = UI.gui
        local black = Color3.fromRGB(0, 0, 0)
        UI.panelTop = mkFrame({
            AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.new(1, 0, 0.5, 0),
            BackgroundColor3 = black, BackgroundTransparency = 0, ZIndex = 20,
        }, gui)
        UI.panelBottom = mkFrame({
            AnchorPoint = Vector2.new(0, 0), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.new(1, 0, 0.5, 0),
            BackgroundColor3 = black, BackgroundTransparency = 0, ZIndex = 20,
        }, gui)
        UI.crt = mkFrame({
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(0, 0, 0, 3),
            BackgroundColor3 = Color3.fromRGB(255, 215, 215), BackgroundTransparency = 0, ZIndex = 21,
        }, gui)
        UI.crtStroke = mkStroke(UI.crt, 4, ACCENT, 0.55)
        UI.flash = mkFrame({
            Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = WHITE, BackgroundTransparency = 1, ZIndex = 30,
        }, gui)

        if AYAR.ATLA_BUTONU then
            UI.skip = mk("TextButton", {
                Name = "Atla", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -16, 1, -10),
                Size = UDim2.new(0, 190, 0, 28), BackgroundTransparency = 1, BorderSizePixel = 0,
                Text = "ATLA  >>  [SPACE]", Font = Enum.Font.GothamBold, TextSize = 12,
                TextColor3 = Color3.fromRGB(175, 115, 120), TextTransparency = 1,
                TextXAlignment = Enum.TextXAlignment.Right, AutoButtonColor = false, ZIndex = 5,
            }, gui)
        end
    end

    ---------------------------------------------------------
    -- Kare döngüsü: yağmur, ızgara, RGB, sarsıntı, HUD canlı veri
    ---------------------------------------------------------
    local function onFrame(dt)
        if ST.done then return end
        local t = os.clock() - ST.t0
        local k = math.min(1, dt * 3)
        ST.rainLevel = ST.rainLevel + (ST.rainTarget - ST.rainLevel) * k
        ST.gridLevel = ST.gridLevel + (ST.gridTarget - ST.gridLevel) * k
        ST.hudLevel = ST.hudLevel + (ST.hudTarget - ST.hudLevel) * k

        -- Ekran + kamera sarsıntısı
        if ST.shake > 0.15 then
            local s = ST.shake
            local rx, ry = (math.random() - 0.5) * 2 * s, (math.random() - 0.5) * 2 * s
            UI.world.Position = UDim2.new(0, rx, 0, ry)
            setCamOffset(rx * 0.02, ry * 0.02)
            ST.shake = s * math.max(0, 1 - dt * 9)
            ST.shaking = true
        elseif ST.shaking then
            ST.shake = 0
            ST.shaking = false
            UI.world.Position = UDim2.new(0, 0, 0, 0)
            setCamOffset(0, 0)
        end

        -- Kod yağmuru
        if #UI.rain > 0 then
            local vh = ST.vp.Y
            local tr = 1 - 0.55 * ST.rainLevel
            local trChanged = math.abs(tr - ST.lastRainTr) > 0.002
            if trChanged then ST.lastRainTr = tr end
            for _, c in ipairs(UI.rain) do
                c.y = c.y + c.speed * dt
                if c.y > vh then
                    c.y = -c.rows * 15 - math.random(0, 160)
                    c.speed = math.random(110, 300)
                end
                c.lbl.Position = UDim2.new(c.x, 0, 0, c.y)
                if trChanged then c.lbl.TextTransparency = tr end
            end
            ST.rainTick = ST.rainTick + dt
            if ST.rainTick > 0.07 then
                ST.rainTick = 0
                for _ = 1, 5 do rainRefresh(UI.rain[math.random(1, #UI.rain)]) end
            end
        end

        local col = kanAt(0)
        ST.tickN = ST.tickN + 1
        local slow = (ST.tickN % 3) == 0

        -- Perspektif ızgara (yatay çizgiler izleyiciye doğru akar)
        if UI.gridGlow then
            local gl = ST.gridLevel
            ST.gridPhase = (ST.gridPhase + dt * 0.55) % 1
            local GH, N = ST.GH, #UI.gridH
            for kk = 1, N do
                local z = ((kk - 1 + ST.gridPhase) / N) % 1
                local ln = UI.gridH[kk]
                ln.Position = UDim2.new(0.5, 0, GH + (1 - GH) * z * z, 0)
                ln.BackgroundTransparency = 1 - gl * (0.08 + 0.7 * z)
            end
            if slow then
                local vt = 1 - gl * 0.8
                for _, ln in ipairs(UI.gridV) do
                    ln.BackgroundTransparency = vt
                    ln.BackgroundColor3 = col
                end
                for _, ln in ipairs(UI.gridH) do ln.BackgroundColor3 = col end
                UI.gridGlow.BackgroundTransparency = 1 - gl
                UI.gridGlow.BackgroundColor3 = col
                UI.gridHorizon.BackgroundTransparency = 1 - gl * 0.9
                UI.gridHorizon.BackgroundColor3 = col
            end
        end

        -- Çemberler + logo renkleri (harf parlaması beyazdan RGB'ye söner)
        for idx, r in ipairs(UI.rings) do
            r.stroke.Color = kanAt(idx * 1.6)
            r.rot = (r.rot + r.speed * dt) % 360
            r.grad.Rotation = r.rot
        end
        for i = 1, LN do
            local c = kanAt(i * 0.6)
            local f = ST.flash[i]
            if f > 0.01 then
                c = c:Lerp(WHITE, f)
                ST.flash[i] = f * math.max(0, 1 - dt * 7)
            end
            if math.random() < 0.010 then c = Color3.fromRGB(14, 0, 0) end -- kısa karanlık titremesi
            UI.layers[3][i].TextColor3 = c
            if UI.hubLayers[3][i] then
                UI.hubLayers[3][i].TextColor3 = kanAt(i * 0.6 + 3.1)
            end
        end
        for _, p in ipairs(UI.bracketParts) do p.BackgroundColor3 = col end
        UI.line.BackgroundColor3 = col
        UI.barFill.BackgroundColor3 = ST.barGreen and GREEN or col
        UI.scan.BackgroundColor3 = col
        UI.scan.Position = UDim2.new(0, 0, (t * 0.55) % 1, 0)
        UI.barTopEdge.BackgroundColor3 = col
        UI.barBottomEdge.BackgroundColor3 = col
        UI.cardStroke.Color = col
        UI.avatarStroke.Color = kanAt(2)
        UI.nameLabel.TextColor3 = kanAt(1)
        UI.avScan.Position = UDim2.new(0, 0, math.sin(t * 2.4) * 0.5 + 0.5, -1)

        -- Karakter hafifçe sağa sola dönsün
        if ST.vpModel and ST.vpModel.Parent and ST.vpBase then
            ST.vpModel:PivotTo(ST.vpBase * CFrame.Angles(0, math.sin(tick() * 1.4) * 0.55, 0))
        end

        -- HUD: yazı görünürlüğü + canlı FPS / PING / saat + imleç yanıp sönmesi
        if UI.term then
            local tr = 1 - 0.9 * ST.hudLevel
            UI.term.TextTransparency = tr
            UI.stats.TextTransparency = tr
            UI.info.TextTransparency = tr
            ST.frames = ST.frames + 1
            ST.fpsAcc = ST.fpsAcc + dt
            ST.pingAcc = ST.pingAcc + dt
            if ST.fpsAcc >= 0.3 then
                ST.fps = math.floor(ST.frames / ST.fpsAcc + 0.5)
                ST.frames, ST.fpsAcc = 0, 0
                updateStats()
            end
            if ST.pingAcc >= 1 then
                ST.pingAcc = 0
                pollPing()
            end
            local blink = (math.floor(t * 2.2) % 2) == 0
            if blink ~= ST.blink then
                ST.blink = blink
                refreshTerm()
            end
        end
    end

    ---------------------------------------------------------
    -- Yükleme ilerlemesi
    ---------------------------------------------------------
    local function progressAt(t)
        for i = 2, #PROG_KEYS do
            local a, b = PROG_KEYS[i - 1], PROG_KEYS[i]
            if t <= b[1] then
                return a[2] + (b[2] - a[2]) * ((t - a[1]) / (b[1] - a[1]))
            end
        end
        return 100
    end

    local function setProgress(p)
        p = math.clamp(p, 0, 100)
        UI.barFill.Size = UDim2.new(p / 100, 0, 1, 0)
        local msg = STATUSES[1][2]
        for _, s in ipairs(STATUSES) do
            if p >= s[1] then msg = s[2] end
        end
        if msg ~= ST.lastMsg then
            if ST.lastMsg ~= "" then
                playSound(1.6, 0.35)
                task.spawn(microGlitch)
            end
            ST.lastMsg = msg
        end
        UI.status.Text = msg .. "  •  " .. math.floor(p) .. "%"
    end

    ---------------------------------------------------------
    -- Menüye geçiş yardımcıları
    ---------------------------------------------------------
    -- Panjur açılışı: karartma şeritleri ortadan dışa doğru sırayla açılır
    local function openShutters()
        local N = 18
        local mid = (N + 1) / 2
        for i = 1, N do
            local fromTop = (i % 2 == 1)
            local s = mkFrame({
                AnchorPoint = Vector2.new(0.5, fromTop and 0 or 1),
                Position = UDim2.new((i - 0.5) / N, 0, fromTop and 0 or 1, 0),
                Size = UDim2.new(1 / N, 1, 1, 0),
                BackgroundColor3 = BG, BackgroundTransparency = 0.12, ZIndex = 1,
            }, UI.gui)
            TweenService:Create(
                s,
                TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut, 0, false, math.abs(i - mid) * 0.035),
                {Size = UDim2.new(1 / N, 1, 0, 0)}
            ):Play()
        end
    end

    ---------------------------------------------------------
    -- Temizlik (normal bitiş + hata durumunda güvenli mod)
    ---------------------------------------------------------
    local function finalizeIntro()
        ST.done = true
        for _, c in ipairs(ST.conns) do
            pcall(function() c:Disconnect() end)
        end
        setCamOffset(0, 0)
        pcall(function() cc:Destroy() end)
        pcall(function() bloom:Destroy() end)
        pcall(function() UI.holder:Destroy() end)
    end

    -- Menüyü açan geri çağırma (onPeak) yalnızca bir kez ve script hâlâ açıkken çalışır
    local function firePeak()
        if ST.peaked or not alive then return end
        ST.peaked = true
        if ST.onPeak then pcall(ST.onPeak) end
    end

    local function forceFinish()
        finalizeIntro()
        -- sürmekte olan tween'ler doğrudan atamayı ezer; yeni tween eskisini iptal eder
        camTween(0.05, ST.origFOV)
        firePeak()
    end

    ---------------------------------------------------------
    -- Giriş senaryosu (fazlar)
    ---------------------------------------------------------
    local function buildIntro()
        local cam = workspace.CurrentCamera
        local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
        if vp.X < 100 or vp.Y < 100 then vp = Vector2.new(1280, 720) end
        ST.vp = vp
        ST.compact = (vp.X < 760) or (vp.Y < 430)
        ST.origFOV = cam and cam.FieldOfView or 70
        pcall(function()
            local ch = LocalPlayer.Character
            local hum = ch and ch:FindFirstChildOfClass("Humanoid")
            if hum then
                ST.hum = hum
                ST.camOff0 = hum.CameraOffset
            end
        end)

        buildBackdrop()
        buildBars()
        buildStage()
        buildHud()
        buildCard()
        buildOverlays()
        refreshInfo()
        updateStats()
        refreshTerm()

        -- Oyun adı (ağdan gelir, hata olursa sessizce geçer)
        task.spawn(function()
            local ok, info = pcall(function() return MarketplaceService:GetProductInfo(game.PlaceId) end)
            if ok and type(info) == "table" and info.Name then
                ST.gameName = esc(clip(info.Name, 26))
            else
                ST.gameName = "bilinmiyor"
            end
            refreshInfo()
        end)

        -- Bağlantılar: kare döngüsü + atlama
        ST.conns[#ST.conns + 1] = RunService.RenderStepped:Connect(onFrame)
        ST.conns[#ST.conns + 1] = UserInputService.InputBegan:Connect(function(input, gpe)
            if gpe or ST.done then return end
            local kc = input.KeyCode
            if kc == Enum.KeyCode.Space or kc == Enum.KeyCode.Return then
                ST.skipped = true
            end
        end)
        if UI.skip then
            ST.conns[#ST.conns + 1] = UI.skip.MouseButton1Click:Connect(function()
                ST.skipped = true
            end)
        end
    end

    -- FAZ 1: CRT açılışı (nokta -> çizgi -> ikiye ayrılıp açılır)
    local function phaseOpen()
        playSound(0.35, 1.0, 2.5)
        tween(UI.crt, 0.34, {Size = UDim2.new(1, 0, 0, 3)}, Enum.EasingStyle.Quint)
        sleep(0.4)
        playSound(1.5, 0.45)
        tween(UI.crt, 0.1, {Size = UDim2.new(1, 0, 0, 8)})
        sleep(0.1)
        tween(UI.panelTop, 0.7, {Position = UDim2.new(0, 0, 0, 0)}, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut)
        tween(UI.panelBottom, 0.7, {Position = UDim2.new(0, 0, 1, 0)}, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut)
        tween(UI.crt, 0.5, {BackgroundTransparency = 1}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        tween(UI.crtStroke, 0.5, {Transparency = 1})

        -- dünya canlanır
        tween(blurEffect, 1.4, {Size = 30})
        tween(cc, 3, {Saturation = 0.25})
        camTween(5, ST.origFOV - 9, Enum.EasingStyle.Linear)
        for _, v in ipairs(UI.vignette) do tween(v, 1, {BackgroundTransparency = 0}) end
        tween(UI.barTop, 0.8, {Size = UDim2.new(1, 0, 0.1, 0)}, Enum.EasingStyle.Quint)
        tween(UI.barBottom, 0.8, {Size = UDim2.new(1, 0, 0.1, 0)}, Enum.EasingStyle.Quint)
        ST.rainTarget, ST.gridTarget, ST.hudTarget = 1, 1, 1
        if UI.skip then tween(UI.skip, 0.6, {TextTransparency = 0.35}) end
        startBootLog()
        sleep(0.65)
    end

    -- FAZ 2: enerji toplanır (halkalar açılır, ışık çizgileri merkeze akar, titreme artar)
    local function phaseCharge()
        startRiser(1.25, 0.5, 2.8, 0.5)
        for i, r in ipairs(UI.rings) do
            tween(r.frame, 0.9 + i * 0.15, {Size = UDim2.new(0, r.size, 0, r.size)}, Enum.EasingStyle.Back)
        end
        tween(UI.brackets, 1, {Size = UDim2.new(0, 540, 0, 170)}, Enum.EasingStyle.Quint)
        for _, p in ipairs(UI.bracketParts) do tween(p, 0.6, {BackgroundTransparency = 0}) end
        tween(UI.halo, 1.2, {Size = UDim2.new(0, 230, 0, 230), BackgroundTransparency = 0.7}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        tween(UI.core, 1.2, {Size = UDim2.new(0, 36, 0, 36)}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

        local t0, dur, n = os.clock(), 1.2, 0
        while not ST.skipped do
            local el = os.clock() - t0
            if el >= dur then break end
            local p = el / dur
            addShake(0.6 + 3.5 * p * p)
            n = n + 1
            if n % 2 == 0 then
                spawnConverge()
                spawnConverge()
                spawnConverge()
            end
            task.wait(0.03)
        end
    end

    -- FAZ 3: PATLAMA + harfler çakılır
    local function phaseImpact()
        playSound(0.4, 1.5, 3)
        playSound(0.8, 0.9)
        addShake(20)
        camSet(ST.origFOV + 6)
        camTween(2.4, ST.origFOV - 10)
        tween(UI.core, 0.45, {Size = UDim2.new(0, 460, 0, 460), BackgroundTransparency = 1}, Enum.EasingStyle.Quint)
        tween(UI.halo, 0.6, {Size = UDim2.new(0, 1100, 0, 1100), BackgroundTransparency = 1}, Enum.EasingStyle.Quint)
        UI.flash.BackgroundTransparency = math.max(FLASH_MIN, 0.55)
        tween(UI.flash, 0.35, {BackgroundTransparency = 1})
        shockwave(10, WHITE, 1900, 0.9)
        shockwave(3, ACCENT, 1300, 1.1)
        burstRays(WHITE)
        burstSparks(40, 700)

        for i = 1, LN do
            task.delay((i - 1) * 0.1, function()
                if not ST.skipped then slamLetter(i) end
            end)
        end
        sleep((LN - 1) * 0.1 + 0.95)
    end

    -- FAZ 4: logo tamamlandı -> parıltı süpürmesi, lens flare, glitch, alt başlık
    -- Logo harflerinden aşağı süzülen kan damlaları
    local function kanDamlat(n)
        for _ = 1, n do
            local i = math.random(1, LN)
            local x = UI.letterBase[i] - LOGO_W / 2 + math.random(-16, 16)
            local w = math.random(2, 4)
            local len = math.random(28, 95)
            local d = mkFrame({
                AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0, x, 0, 30),
                Size = UDim2.new(0, w, 0, 2), BackgroundColor3 = Color3.fromRGB(170, 0, 10),
                BackgroundTransparency = 0, ZIndex = 6,
            }, UI.stage)
            mk("UICorner", {CornerRadius = UDim.new(1, 0)}, d)
            local dur = 0.9 + math.random() * 1.3
            tween(d, dur, {Size = UDim2.new(0, w, 0, len)}, Enum.EasingStyle.Quad)
            task.delay(dur * 0.55, function()
                tween(d, dur * 0.7, {Position = UDim2.new(0, x, 0, 30 + len * 0.6), BackgroundTransparency = 1}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
            end)
            task.delay(dur * 1.4 + 0.1, function() pcall(function() d:Destroy() end) end)
        end
    end

    -- HUB yazısı: logo sola kayar, H-U-B sırayla büyükten çakılır
    local function hubGoster()
        -- logo + HUB birlikte ekranda ortalı dursun
        local shift = -(UI.hubGap + UI.hubW) / 2
        UI.logoX = shift
        tween(UI.logoHolder, 0.45, {Position = UDim2.new(0, shift, 0, -12)}, Enum.EasingStyle.Quint)
        tween(UI.hubHolder, 0.45, {Position = UDim2.new(0, UI.hubX + shift, 0, -12)}, Enum.EasingStyle.Quint)
        sleep(0.2)
        for i = 1, #UI.hubText do
            if ST.skipped or ST.done then return end
            task.spawn(function()
                local sc = UI.hubScale[i]
                sc.Scale = 3.4
                for li = 1, 3 do
                    UI.hubLayers[li][i].TextTransparency = 1
                    tween(UI.hubLayers[li][i], 0.14, {TextTransparency = LAYERS[li].trans})
                end
                tween(sc, 0.24, {Scale = 1}, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
                -- çözülme: rastgele karakterlerden gerçek harfe
                local t0 = os.clock()
                while os.clock() - t0 < 0.3 and not ST.skipped do
                    for li = 1, 3 do UI.hubLayers[li][i].Text = randChar() end
                    task.wait(0.04)
                end
                for li = 1, 3 do UI.hubLayers[li][i].Text = UI.hubText:sub(i, i) end
                if ST.skipped or ST.done then return end
                -- darbe: kıvılcım + sarsıntı + kan damlası
                playSound(1.4 + i * 0.15, 0.5)
                addShake(7)
                burstSparks(8, 160)
                kanDamlat(2)
            end)
            sleep(0.14)
        end
    end

    local function phaseLogoFinish()
        playSound(2.2, 0.5)
        burstRays(ACCENT)
        for i = 1, LN do
            task.delay((i - 1) * 0.06, function() sweepShine(i) end)
        end
        UI.flare.Size = UDim2.new(0, 0, 0, 5)
        UI.flare.BackgroundTransparency = 0
        tween(UI.flare, 0.5, {Size = UDim2.new(0, 1100, 0, 2)}, Enum.EasingStyle.Quint)
        tween(UI.flare, 0.8, {BackgroundTransparency = 1}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        tween(UI.line, 0.5, {Size = UDim2.new(0, 460, 0, 2)}, Enum.EasingStyle.Quint)
        task.spawn(function() typeX(UI.sub, spaced(trText(SUB_TEXT)), 0.03) end)
        glitchBurst(10, 8)
        task.spawn(function()
            sleep(0.25)
            hubGoster()
        end)
        task.spawn(function()
            for _ = 1, 6 do
                if ST.done or ST.skipped then break end
                kanDamlat(3)
                task.wait(0.35)
            end
        end)
        sleep(0.2)
    end

    -- FAZ 5: yükleme (çubuk + durum yazısı + oyuncu kartı)
    local function phaseLoad()
        tween(UI.barBG, 0.3, {BackgroundTransparency = 0.2})
        tween(UI.barFill, 0.3, {BackgroundTransparency = 0})
        tween(UI.barStroke, 0.3, {Transparency = 0.6})
        tween(UI.spark, 0.3, {BackgroundTransparency = 0.1})
        tween(UI.status, 0.3, {TextTransparency = 0})

        task.spawn(function()
            playSound(1.3, 0.7)
            tween(UI.card, 0.8, {Position = UDim2.new(0.5, 0, 0.9, -6)}, Enum.EasingStyle.Back)
            task.wait(0.5)
            tween(UI.pill, 0.4, {TextTransparency = 0})
            typeX(UI.welcome, "HOŞ GELDİN,", 0.03)
            local shown = LocalPlayer.DisplayName
            if not shown or shown == "" then shown = LocalPlayer.Name end
            typeX(UI.nameLabel, shown, 0.04)
            tween(UI.handle, 0.5, {TextTransparency = 0})
        end)

        local t0 = os.clock()
        local total = PROG_KEYS[#PROG_KEYS][1]
        while not ST.skipped do
            local t = os.clock() - t0
            if t >= total then break end
            setProgress(progressAt(t))
            task.wait()
        end
        if not ST.skipped then setProgress(100) end
        sleep(0.25)
    end

    -- FAZ 6: "ERİŞİM ONAYLANDI" mührü
    local function phaseAccess()
        ST.barGreen = true
        UI.status.Text = "Hazır!  •  100%"
        UI.stamp.TextTransparency = 0
        UI.stampScale.Scale = 1.9
        tween(UI.stampScale, 0.35, {Scale = 1}, Enum.EasingStyle.Back)
        playSound(1.0, 0.8)
        task.delay(0.12, function() playSound(1.5, 0.8) end)
        task.delay(0.24, function() playSound(2.0, 0.8) end)
        for i = 1, LN do ST.flash[i] = 1 end
        addShake(7)
        shockwave(4, GREEN, 900, 0.8)
        burstSparks(18, 380, GREEN)
        glitchSlices(5)
        sleep(0.75)
    end

    -- FAZ 7: büyük çıkış -> flaş -> panjur açılışı -> menü patlayarak gelir
    local function phaseOutro()
        local d = ST.skipped and 0.28 or 0.42
        playSound(0.45, 1.4, 2.5)
        burstRays(WHITE)
        burstSparks(36, 900)
        for _, r in ipairs(UI.rings) do
            tween(r.frame, d + 0.03, {Size = UDim2.new(0, 1900, 0, 1900)}, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
        end
        local mid = (LN + 1) / 2
        for i = 1, LN do
            local dx = (i - mid) * (LETTER_W + LETTER_GAP) * 1.7
            tween(UI.letterBox[i], d, {Position = UDim2.new(0, UI.letterBase[i] + dx, 0.5, 0)}, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
            tween(UI.letterScale[i], d, {Scale = 2.6}, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
            for li = 1, 3 do
                tween(UI.layers[li][i], d, {TextTransparency = 1}, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
            end
        end
        for i = 1, #UI.hubText do
            tween(UI.hubScale[i], d, {Scale = 2.6}, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
            tween(UI.hubBox[i], d, {Position = UDim2.new(0, UI.hubBox[i].Position.X.Offset + i * 90, 0.5, 0)}, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
            for li = 1, 3 do
                tween(UI.hubLayers[li][i], d, {TextTransparency = 1}, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
            end
        end
        tween(UI.line, 0.3, {Size = UDim2.new(0, 0, 0, 2)})
        tween(UI.sub, 0.3, {TextTransparency = 1})
        tween(UI.status, 0.3, {TextTransparency = 1})
        tween(UI.barBG, 0.3, {BackgroundTransparency = 1})
        tween(UI.barFill, 0.3, {BackgroundTransparency = 1})
        tween(UI.barStroke, 0.3, {Transparency = 1})
        tween(UI.spark, 0.3, {BackgroundTransparency = 1})
        tween(UI.stamp, 0.3, {TextTransparency = 1})
        tween(UI.brackets, d, {Size = UDim2.new(0, 1100, 0, 560)}, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
        for _, p in ipairs(UI.bracketParts) do tween(p, d, {BackgroundTransparency = 1}) end
        tween(UI.card, d, {Position = UDim2.new(0.5, 0, 1.5, 0)}, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
        tween(UI.barTop, d, {Size = UDim2.new(1, 0, 0, 0)})
        tween(UI.barBottom, d, {Size = UDim2.new(1, 0, 0, 0)})
        if UI.skip then tween(UI.skip, 0.2, {TextTransparency = 1}) end
        ST.rainTarget, ST.gridTarget, ST.hudTarget = 0, 0, 0
        addShake(10)
        task.wait(d - 0.05)

        -- Flaş
        tween(UI.flash, 0.1, {BackgroundTransparency = FLASH_MIN})
        task.wait(0.12)

        -- Flaşın tepesinde: giriş kalkar, panjurlar açılır, menü patlayarak gelir
        UI.world.Visible = false
        for _, v in ipairs(UI.vignette) do v.Visible = false end
        UI.barTop.Visible = false
        UI.barBottom.Visible = false
        UI.panelTop.Visible = false
        UI.panelBottom.Visible = false
        UI.crt.Visible = false
        if UI.skip then UI.skip.Visible = false end
        UI.dim.BackgroundTransparency = 1
        openShutters()
        firePeak() -- ana menü burada açılır

        cc.Brightness = 0.3
        tween(cc, 0.9, {Brightness = 0, Saturation = 0, Contrast = 0, TintColor = Color3.new(1, 1, 1)})
        bloom.Intensity = 2.2
        tween(bloom, 1.1, {Intensity = 0})
        camSet(ST.origFOV + 15)
        camTween(1, ST.origFOV, Enum.EasingStyle.Quint)
        tween(UI.flash, 0.6, {BackgroundTransparency = 1})

        task.wait(1.0)
        finalizeIntro()
    end


    ---------------------------------------------------------
    -- Giriş akışı (dışarıya açılan tek fonksiyon)
    ---------------------------------------------------------
    function I.play(onPeak)
        AYAR.SES = Settings.Sound
        ST.onPeak = onPeak
        UI_SCALE = introScale()

        -- Işık efektleri: dünya siyah-kırmızı, bloom giriş sonunda parlar
        pcall(function()
            cc.Saturation = -1
            cc.TintColor = Color3.fromRGB(255, 110, 110)
        end)
        pcall(function()
            bloom = Instance.new("BloomEffect")
            bloom.Name = "EZRAGOX_Bloom"
            bloom.Intensity = 0
            bloom.Size = 24
            bloom.Threshold = 0.8
            bloom.Parent = Lighting
        end)

        -- Arayüz kapatılırsa (closeAll) kamera / efektler geri alınır
        task.spawn(function()
            while not ST.done do
                if not alive then
                    ST.skipped = true
                    finalizeIntro()
                    pcall(function()
                        local c = workspace.CurrentCamera
                        if c then c.FieldOfView = ST.origFOV end
                    end)
                    return
                end
                task.wait(0.15)
            end
        end)

        -- Güvenlik ağı: giriş 25 sn içinde bitmezse menü doğrudan açılır
        task.delay(25, function()
            if not ST.done then
                ST.skipped = true
                warn("[EZRAGOX] Giriş zaman aşımına uğradı, menü doğrudan açılıyor")
                forceFinish()
            end
        end)

        local ok, err = pcall(function()
            buildIntro()
            ST.t0 = os.clock()
            local phases = {phaseOpen, phaseCharge, phaseImpact, phaseLogoFinish, phaseLoad, phaseAccess}
            for _, ph in ipairs(phases) do
                if ST.skipped then break end
                ph()
            end
            phaseOutro()
        end)
        if not ok then
            warn("[EZRAGOX] Giriş animasyonunda hata (menü doğrudan açılıyor): " .. tostring(err))
            forceFinish()
        end
    end

    return I
end)()

---------------------------------------------------------
-- 2. ANA MENÜ ÇERÇEVESİ
---------------------------------------------------------
local W, H = tonumber(Settings.WinW) or 720, tonumber(Settings.WinH) or 560
local ready = false
local menuOpen = false

local Window = new("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.5, 0, 0.5, 0),
    Size = UDim2.new(0, 0, 0, 0),
    BackgroundTransparency = 1,
    ZIndex = 10,
}, ScreenGui)

local MainFrame = new("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0, 0, 0, 0),
    Size = UDim2.new(0, W, 0, H),
    BackgroundColor3 = Color3.new(1, 1, 1),
    BackgroundTransparency = 0.04,
    BorderSizePixel = 0,
    Active = true,
    Visible = false,
}, Window)
corner(MainFrame, 22)
new("UIGradient", {
    Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 8, 13)),
        ColorSequenceKeypoint.new(0.48, Color3.fromRGB(13, 8, 12)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(5, 5, 8)),
    }),
    Rotation = 105,
}, MainFrame)
-- İnce cam katmanı ve üstten gelen yumuşak neon ışık
local ShellGlow = new("Frame", {
    Position = UDim2.new(0, 2, 0, 2), Size = UDim2.new(1, -4, 0, 92),
    BackgroundColor3 = Color3.fromRGB(150, 12, 28), BackgroundTransparency = 0.84,
    BorderSizePixel = 0, ZIndex = 1,
}, MainFrame)
corner(ShellGlow, 20)
new("UIGradient", {Rotation = 90, Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 0.18), NumberSequenceKeypoint.new(1, 1),
})}, ShellGlow)
local MainScale = new("UIScale", {Scale = 1}, MainFrame)
local MainStroke = stroke(MainFrame, 2, Color3.new(1, 1, 1))
regFlow(UIFlows, new("UIGradient", {}, MainStroke), 0, 0.9, 60)

local GlowFrame = new("Frame", {
    -- Dış neon boşluğu iki tarafta eşit; panel kenarları kırpılmaz.
    Size = UDim2.new(1, 22, 1, 22),
    Position = UDim2.new(0, -11, 0, -11),
    BackgroundTransparency = 1,
    ZIndex = 0,
}, MainFrame)
corner(GlowFrame, 26)
local GlowStroke = stroke(GlowFrame, 8, Color3.new(1, 1, 1), 0.91)
regFlow(UIFlows, new("UIGradient", {}, GlowStroke), 1, 0.9, 60)
-- Koyu kırmızı dış aura; mevcut gradient döngüsüyle sürekli ve hafif hareket eder.
local RedAura = new("Frame", {
    Size = UDim2.new(1, 10, 1, 10),
    Position = UDim2.new(0, -5, 0, -5),
    BackgroundTransparency = 1,
    ZIndex = 0,
}, MainFrame)
corner(RedAura, 25)
local RedAuraStroke = stroke(RedAura, 2, Color3.fromRGB(255, 28, 48), 0.72)
Pulsers[#Pulsers + 1] = {obj = RedAuraStroke, prop = "Transparency", base = 0.72, amp = 0.16, speed = 1.8}

---------------------------------------------------------
-- 3. ÜST BAŞLIK
---------------------------------------------------------
local Header = new("Frame", {Size = UDim2.new(1, 0, 0, 76), BackgroundTransparency = 1, Active = true, ZIndex = 2}, MainFrame)
local HeaderAccent = new("Frame", {
    Position = UDim2.new(0, 18, 1, -2), Size = UDim2.new(1, -36, 0, 2),
    BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 3,
}, Header)
regFlow(UIFlows, new("UIGradient", {}, HeaderAccent), 0, 0.75, 35)

-- Sol üst logo: dairesel kapsayıcı görseli gerçekten yuvarlak kırpar.
local LogoCircle = new("Frame", {
    Position = UDim2.new(0, 20, 0, 16),
    Size = UDim2.new(0, 44, 0, 44),
    BackgroundColor3 = Color3.fromRGB(20, 5, 10),
    BorderSizePixel = 0,
    ClipsDescendants = true,
    ZIndex = 3,
}, Header)
corner(LogoCircle, 999)
local LogoMark = new("ImageLabel", {
    Position = UDim2.new(0, 0, 0, 0),
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Image = "rbxassetid://70705306364149",
    ScaleType = Enum.ScaleType.Crop,
    ImageTransparency = 0,
    ZIndex = 4,
}, LogoCircle)
-- Görselin kendisine de dairesel köşe uygula; böylece kare görüntü kenarı kalmaz.
corner(LogoMark, 999)
task.spawn(function()
    local cp = game:GetService("ContentProvider")
    pcall(function() cp:PreloadAsync({LogoMark}) end)
    if not LogoMark.IsLoaded then
        LogoMark.Image = "rbxthumb://type=Asset&id=70705306364149&w=420&h=420"
        pcall(function() cp:PreloadAsync({LogoMark}) end)
    end
end)

-- Üst marka başlığı
local BrandRow = new("Frame", {
    BackgroundTransparency = 1,
    Size = UDim2.new(1, -190, 0, 30),
    Position = UDim2.new(0, 76, 0, 12),
    ZIndex = 3,
}, Header)
new("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal,
    HorizontalAlignment = Enum.HorizontalAlignment.Left,
    VerticalAlignment = Enum.VerticalAlignment.Center,
    Padding = UDim.new(0, 8),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, BrandRow)

-- Birleşik EZRAGOX HUB logosu: eski ayrı logo ve HUB rozeti kaldırıldı.
local BrandTitle = new("ImageLabel", {
    AnchorPoint = Vector2.new(0, 0),
    Position = UDim2.new(0, 70, 0, 3),
    Size = UDim2.new(0, 238, 0, 54),
    BackgroundTransparency = 1,
    Image = "rbxassetid://132651627732258",
    ScaleType = Enum.ScaleType.Fit,
    ImageTransparency = 0,
    ZIndex = 3,
}, Header)

-- Logo yükleme; gerekirse küçük resim adresini dene.
task.spawn(function()
    local cp = game:GetService("ContentProvider")
    pcall(function() cp:PreloadAsync({BrandTitle}) end)
    if not BrandTitle.IsLoaded then
        BrandTitle.Image = "rbxthumb://type=Asset&id=132651627732258&w=420&h=420"
        pcall(function() cp:PreloadAsync({BrandTitle}) end)
    end
end)

-- SÜZÜLME ANİMASYONU: logo, baştaki yuvarlak logodan küçültme tuşuna kadar
-- yavaşça süzülüp geri gelir. Düz çizgi değil: yumuşak hızlanıp yavaşlar (cos),
-- dalga gibi yukarı-aşağı salınır ve hafifçe yalpalar.
-- Ayarlar: GLIDE_PERIOD = bir gidiş-dönüş süresi (sn), GLIDE_BOB = dikey dalga (px),
--          GLIDE_TILT = yalpalama (derece), GLIDE_WAVES = bir gidiş-dönüşte kaç dalga
do
    local GLIDE_PERIOD = 12
    local GLIDE_BOB = 4
    local GLIDE_TILT = 2.2
    local GLIDE_WAVES = 3
    local LEFT_PAD = 70     -- yuvarlak logonun hemen sağı
    local RIGHT_GAP = 88    -- küçültme + kapat tuşları için sağdan boşluk
    local phase = 0
    local glideAcc = 0
    bind(RunService.RenderStepped, function(dt)
        if not BrandTitle.Parent or not MainFrame.Visible then return end
        glideAcc = glideAcc + dt
        if glideAcc < 1 / 30 then return end
        dt = glideAcc
        glideAcc = 0
        phase = (phase + dt / GLIDE_PERIOD) % 1
        local s = (1 - math.cos(phase * math.pi * 2)) / 2          -- 0 -> 1 -> 0, uçlarda yavaşlar
        local wave = math.sin(phase * math.pi * 2 * GLIDE_WAVES)
        -- AnchorPoint.X = s hilesi: sol kenar ile sağ kenar arasında panel genişliğinden bağımsız süzülür
        BrandTitle.AnchorPoint = Vector2.new(s, 0)
        BrandTitle.Position = UDim2.new(s, LEFT_PAD - s * (RIGHT_GAP + LEFT_PAD), 0, 3 + wave * GLIDE_BOB)
        BrandTitle.Rotation = math.sin(phase * math.pi * 2 * GLIDE_WAVES + 1.2) * GLIDE_TILT
    end)
end

local BrandTagline = new("TextLabel", {
    Size = UDim2.new(1, -190, 0, 16),
    Position = UDim2.new(0, 76, 0, 46),
    BackgroundTransparency = 1,
    Text = "TÜRK TROLL SCRİPTİ   /   HİLE İŞİ GÖNÜL İŞİ   •   v6.6",
    TextColor3 = Color3.fromRGB(255, 70, 82),
    TextSize = 11,
    Font = Enum.Font.GothamBold,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd,
    ZIndex = 3,
}, Header)
local TaglineGradient = new("UIGradient", {
    Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(135, 12, 28)),
        ColorSequenceKeypoint.new(0.45, Color3.fromRGB(255, 65, 78)),
        ColorSequenceKeypoint.new(0.72, Color3.fromRGB(255, 150, 135)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 10, 28)),
    }),
    Rotation = 0,
}, BrandTagline)
regFlow(UIFlows, TaglineGradient, 0.15, 0.8, 0)
local TaglineStroke = stroke(BrandTagline, 1, Color3.fromRGB(255, 35, 55), 0.78)
Pulsers[#Pulsers + 1] = {
    obj = TaglineStroke,
    prop = "Transparency",
    base = 0.72,
    amp = 0.18,
    speed = 2.2,
}

---------------------------------------------------------
-- ORTAK BUTON EFEKTİ  (Premium butonundaki efektlerin birebir aynısı)
--   üstüne gelince: büyüme + ışık süpürmesi + kırmızı parlayan çerçeve + "tik-ti" sesi
--   basınca: içeri çökme + dokunma dalgası + kıvılcım + bas tıkı
--   bırakınca: yaylanarak geri dönme; tıklanınca: onay sesleri + yeşil flaş
-- opts: stroke, radius, visual, also, scale, colors=false, overlay=false, hoverBg, pressBg, persist
---------------------------------------------------------
local ctaFx, fxResetAll
do
local FX_HOT = Color3.fromRGB(255, 70, 85)
local FX_OK = Color3.fromRGB(70, 235, 130)
local FxResets = {}
function fxResetAll(keepPersistent)
    for _, r in ipairs(FxResets) do
        if not (keepPersistent and r.persist) then r.fn() end
    end
end

function ctaFx(input, opts)
    opts = opts or {}
    local visual = opts.visual or input
    local radius = opts.radius or 12
    local hoverScale = opts.hoverScale or 1.025
    local pressScale = opts.pressScale or 0.955
    local colors = opts.colors ~= false

    local scale = opts.scale or visual:FindFirstChildOfClass("UIScale") or new("UIScale", {Scale = 1}, visual)
    local extraScales = {}
    for _, o in ipairs(opts.also or {}) do
        extraScales[#extraScales + 1] = o:FindFirstChildOfClass("UIScale") or new("UIScale", {Scale = 1}, o)
    end
    local function setScale(t, v, style)
        tween(scale, t, {Scale = v}, style)
        for _, sc in ipairs(extraScales) do tween(sc, t, {Scale = v}, style) end
    end

    local st = opts.stroke
    local useBg = colors and visual.BackgroundTransparency < 0.99
    local baseBg = visual.BackgroundColor3
    local hoverBg = opts.hoverBg or baseBg:Lerp(Color3.new(1, 1, 1), 0.12)
    local pressBg = opts.pressBg or hoverBg:Lerp(Color3.new(1, 1, 1), 0.08)
    local baseStroke
    if colors then
        if not st then st = stroke(visual, 1.2, FX_HOT, 1) end
        st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        baseStroke = {Color = st.Color, Transparency = st.Transparency, Thickness = st.Thickness}
    end

    -- Işık ve kıvılcımlar düğmenin dışına taşmasın diye kırpılan ayrı bir katmanda çalışır.
    local fxLayer, shine, shineGrad
    if opts.overlay ~= false then
        fxLayer = new("Frame", {
            Name = "FxLayer", Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1,
            BorderSizePixel = 0, ClipsDescendants = true, Active = false, ZIndex = visual.ZIndex + 2,
        }, visual)
        corner(fxLayer, radius)
        shine = new("Frame", {
            Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.new(1, 1, 1),
            BorderSizePixel = 0, ZIndex = visual.ZIndex + 3, Visible = false,
        }, fxLayer)
        corner(shine, radius)
        shineGrad = new("UIGradient", {
            Rotation = 20,
            Offset = Vector2.new(-1, 0),
            Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 1),
                NumberSequenceKeypoint.new(0.4, 1),
                NumberSequenceKeypoint.new(0.5, 0.82),
                NumberSequenceKeypoint.new(0.6, 1),
                NumberSequenceKeypoint.new(1, 1),
            }),
        }, shine)
    end

    local hovering, pressed, shineRun = false, false, 0

    local function sweepShine()
        if not shine then return end
        shineRun = shineRun + 1
        local my = shineRun
        shineGrad.Offset = Vector2.new(-1, 0)
        shine.Visible = true
        tween(shineGrad, 0.6, {Offset = Vector2.new(1, 0)}, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
        task.delay(0.65, function()
            if shineRun == my then shine.Visible = false end
        end)
    end

    -- Dokunma dalgası + kıvılcımlar (fx: dokunulan yatay konum, 0..1)
    local function touchFx(fx)
        if not fxLayer then return end
        local z = visual.ZIndex + 3
        local r = new("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(fx, 0, 0.5, 0),
            Size = UDim2.new(0, 0, 0, 0),
            BackgroundColor3 = Color3.fromRGB(255, 120, 130),
            BackgroundTransparency = 0.55,
            BorderSizePixel = 0, ZIndex = z,
        }, fxLayer)
        pill(r)
        tween(r, 0.6, {Size = UDim2.new(0, 520, 0, 520), BackgroundTransparency = 1}, Enum.EasingStyle.Quint)
        task.delay(0.65, function() r:Destroy() end)
        for i = 1, 8 do
            local a = (i / 8) * math.pi * 2 + math.random() * 0.5
            local d = math.random(26, 74)
            local sz = math.random(3, 5)
            local sp = new("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(fx, 0, 0.5, 0),
                Size = UDim2.new(0, sz, 0, sz),
                BackgroundColor3 = (i % 2 == 0) and Color3.new(1, 1, 1) or Color3.fromRGB(255, 90, 105),
                BorderSizePixel = 0, ZIndex = z,
            }, fxLayer)
            pill(sp)
            local dur = 0.3 + math.random() * 0.2
            tween(sp, dur, {
                Position = UDim2.new(fx, math.cos(a) * d, 0.5, math.sin(a) * d),
                BackgroundTransparency = 1,
            }, Enum.EasingStyle.Quad)
            task.delay(dur + 0.05, function() sp:Destroy() end)
        end
    end

    local function restState(t)
        if not colors or not visual.Parent then return end
        if useBg then
            tween(visual, t, {BackgroundColor3 = hovering and hoverBg or baseBg}, Enum.EasingStyle.Quint)
        end
        tween(st, t, {
            Color = hovering and FX_HOT or baseStroke.Color,
            Transparency = hovering and 0 or baseStroke.Transparency,
            Thickness = hovering and 2 or baseStroke.Thickness,
        }, Enum.EasingStyle.Quint)
    end

    -- ÜSTÜNE GELİNCE
    bind(input.MouseEnter, function()
        hovering = true
        if not pressed then setScale(0.25, hoverScale, Enum.EasingStyle.Back) end
        restState(0.2)
        sweepShine()
        playSound(1.85, 0.12)
        task.delay(0.055, function() playSound(2.3, 0.09) end)
    end)
    bind(input.MouseLeave, function()
        hovering = false
        pressed = false
        setScale(0.25, 1, Enum.EasingStyle.Quint)
        restState(0.24)
    end)

    -- BASINCA (fare ya da dokunmatik)
    bind(input.InputBegan, function(io)
        local ut = io.UserInputType
        if ut ~= Enum.UserInputType.MouseButton1 and ut ~= Enum.UserInputType.Touch then return end
        pressed = true
        setScale(0.07, pressScale, Enum.EasingStyle.Quad)
        if colors then
            if useBg then tween(visual, 0.07, {BackgroundColor3 = pressBg}, Enum.EasingStyle.Quad) end
            tween(st, 0.07, {Color = Color3.new(1, 1, 1), Transparency = 0, Thickness = 2.6}, Enum.EasingStyle.Quad)
        end
        local fx = 0.5
        pcall(function()
            fx = math.clamp((io.Position.X - visual.AbsolutePosition.X) / visual.AbsoluteSize.X, 0, 1)
        end)
        touchFx(fx)
        playSound(1.0, 0.22) -- hafif "bas" tıkı
    end)
    -- BIRAKINCA: yaylanarak geri döner
    bind(input.InputEnded, function(io)
        local ut = io.UserInputType
        if ut ~= Enum.UserInputType.MouseButton1 and ut ~= Enum.UserInputType.Touch then return end
        if not pressed then return end
        pressed = false
        setScale(0.34, hovering and hoverScale or 1, Enum.EasingStyle.Back)
        restState(0.25)
    end)

    -- TIKLANINCA: onay sesleri + yeşil flaş
    bind(input.Activated, function()
        playClickSound()
        task.delay(0.08, function() playSound(2.0, 0.35) end)
        task.delay(0.17, function() playSound(2.7, 0.3) end)
        if colors and visual.Parent then
            tween(st, 0.12, {Color = FX_OK, Transparency = 0, Thickness = 3}, Enum.EasingStyle.Quad)
            task.delay(0.7, function() if alive then restState(0.3) end end)
        end
    end)

    -- Menü gizlenip tekrar açılınca / sekme değişince takılı kalan efekt durumunu sıfırla
    FxResets[#FxResets + 1] = {persist = opts.persist, fn = function()
        if not hovering and not pressed then return end
        hovering, pressed = false, false
        scale.Scale = 1
        for _, sc in ipairs(extraScales) do sc.Scale = 1 end
        if colors and visual.Parent then
            if useBg then visual.BackgroundColor3 = baseBg end
            st.Color, st.Transparency, st.Thickness = baseStroke.Color, baseStroke.Transparency, baseStroke.Thickness
        end
    end}
end
end

local function makeIconButton(text, xOff, hoverColor)
    local b = new("TextButton", {
        Size = UDim2.new(0, 32, 0, 32),
        Position = UDim2.new(1, xOff, 0, 21),
        BackgroundColor3 = Color3.fromRGB(28, 10, 16),
        AutoButtonColor = false,
        Text = text,
        TextColor3 = Color3.new(1, 1, 1),
        TextSize = 18,
        Font = Enum.Font.GothamBold,
        ZIndex = 4,
    }, Header)
    corner(b, 9)
    -- Kapat simgesi: yazı tipinde bozuk çıkmasın diye sekme simgeleri gibi çizgilerle çizilir.
    if text == "✕" then
        setText(b, "")
        -- Küçültme simgesi gibi hep beyaz kalır; üstüne gelince yalnızca arka plan kırmızılaşır.
        for _, rot in ipairs({45, -45}) do
            local f = new("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(0.5, 0, 0.5, 0),
                Size = UDim2.new(0, 2, 0, 16),
                Rotation = rot,
                BackgroundColor3 = Color3.new(1, 1, 1),
                BorderSizePixel = 0,
                ZIndex = 5,
            }, b)
            corner(f, 1)
        end
    end
    ctaFx(b, {radius = 9, hoverBg = hoverColor, pressBg = hoverColor:Lerp(Color3.new(1, 1, 1), 0.12)})
    return b
end
local MinimizeBtn = makeIconButton("–", -84, Color3.fromRGB(105, 18, 32))
local CloseBtn = makeIconButton("✕", -46, Color3.fromRGB(210, 25, 45))

local Divider = new("Frame", {
    Position = UDim2.new(0, 18, 0, 76), Size = UDim2.new(1, -36, 0, 1),
    BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.55, BorderSizePixel = 0, ZIndex = 2,
}, MainFrame)
regFlow(UIFlows, new("UIGradient", {}, Divider), 0, 0.9)

local function makeDraggable(handle, target)
    local dragging, moved = false, false
    local startPos, startInput
    bind(handle.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging, moved = true, false
            startInput = input.Position
            startPos = target.Position
        end
    end)
    bind(UserInputService.InputChanged, function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - startInput
            if d.Magnitude > 6 then moved = true end
            if moved then
                target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
            end
        end
    end)
    bind(UserInputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    return function() return moved end
end
makeDraggable(Header, Window)

---------------------------------------------------------
-- 4. BİLDİRİMLER
---------------------------------------------------------
local ToastHolder = new("Frame", {
    AnchorPoint = Vector2.new(1, 1),
    Position = UDim2.new(1, -16, 1, -6), -- biraz daha aşağı çekildi
    Size = UDim2.new(0, 270, 1, -22),
    BackgroundTransparency = 1,
    ZIndex = 500,
}, ScreenGui)
new("UIListLayout", {
    SortOrder = Enum.SortOrder.LayoutOrder,
    VerticalAlignment = Enum.VerticalAlignment.Bottom,
    Padding = UDim.new(0, 8),
}, ToastHolder)
local toastOrder = 0

-- Sağ alttaki bildirimler kapalı. Tekrar açmak için false yerine true yaz.
local BILDIRIMLER_ACIK = true
-- Script açılışında, önceden açık bırakılmış özellikler otomatik olarak geri yüklenirken
-- bildirim göstermesin diye (aksi halde her girişte 'X Aktif' bildirimleri art arda çıkar).
local suppressNotify = false

local function notify(title, text, duration)
    if not BILDIRIMLER_ACIK or suppressNotify then return end
    if Settings.Sound and (Settings.NotificationVolume or 0) > 0 then
        playSound(1.0, (Settings.NotificationVolume / 100) * 0.65)
    end
    title = trText(title)
    text = trText(text or "")
    toastOrder = toastOrder + 1
    -- Panelin imza görünümü: diyagonal kırmızı/kömür degrade + nabız gibi parlayan kenarlık
    local t = new("CanvasGroup", {
        LayoutOrder = toastOrder,
        Size = UDim2.new(1, 0, 0, 54),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        GroupTransparency = 1,
    }, ToastHolder)
    corner(t, 12)
    -- Degrade yalnızca arka plan katmanında olmalı; CanvasGroup üzerine konursa
    -- Roblox tüm grubu (TextLabel yazıları dahil) renklendirebilir.
    local toastBg = new("Frame", {
        Name = "ToastBackground",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.fromRGB(23, 11, 16),
        BorderSizePixel = 0,
        ZIndex = 1,
    }, t)
    corner(toastBg, 12)
    new("UIGradient", {
        Rotation = 0,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(43, 13, 21)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(23, 11, 16)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(13, 9, 13)),
        }),
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.08),
            NumberSequenceKeypoint.new(1, 0.35),
        }),
    }, toastBg)
    local glowStroke = stroke(t, 1.5, Color3.fromRGB(255, 45, 65), 0.45)
    local bar = new("Frame", {Size = UDim2.new(0, 4, 1, 0), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 2}, t)
    local barGrad = new("UIGradient", {Rotation = 90}, bar)
    new("TextLabel", {
        Position = UDim2.new(0, 16, 0, 8), Size = UDim2.new(1, -26, 0, 18), BackgroundTransparency = 1,
        Text = title, Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = Color3.fromRGB(255, 255, 255),
        TextTransparency = 0, TextStrokeTransparency = 1, RichText = false, ZIndex = 2,
        TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
    }, t)
    new("TextLabel", {
        Position = UDim2.new(0, 16, 0, 27), Size = UDim2.new(1, -26, 0, 18), BackgroundTransparency = 1,
        Text = text or "", Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = Color3.fromRGB(255, 255, 255),
        TextTransparency = 0, TextStrokeTransparency = 1, RichText = false, ZIndex = 2,
        TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
    }, t)
    local scale = new("UIScale", {Scale = 0.9}, t)

    -- Bu bildirimin kendi akan degrade + nabız bağlantısı: yok olunca kendini kapatır,
    -- global Pulsers/UIFlows listelerine eklenmediği için birikip performans düşürmez.
    -- Performans: her karede Lua calistirmak yerine motor tarafinda dongulu tween kullanilir
    barGrad.Color = notifFlowSeq(math.random() * 5, 0.5)
    glowStroke.Transparency = 0.27
    TweenService:Create(glowStroke, TweenInfo.new(1.0, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {Transparency = 0.63}):Play()

    tween(t, 0.28, {GroupTransparency = 0})
    tween(scale, 0.32, {Scale = 1}, Enum.EasingStyle.Back)
    task.delay(duration or 3, function()
        if t.Parent then
            tween(t, 0.3, {GroupTransparency = 1})
            tween(scale, 0.3, {Scale = 0.92})
            task.delay(0.35, function() t:Destroy() end)
        end
    end)
end

-- Panelin ÜSTÜNDE çıkan bildirim (BILDIRIMLER_ACIK kapalı olsa bile çalışır)
local notifyTop
do
local activeTopToast = nil
function notifyTop(text, duration, width)
    if suppressNotify then return end
    if activeTopToast and activeTopToast.Parent then activeTopToast:Destroy() end
    local panelPos, panelSize = MainFrame.AbsolutePosition, MainFrame.AbsoluteSize
    -- Panelin imza görünümü: diyagonal kırmızı/kömür degrade + nabız gibi parlayan kenarlık
    local toast = new("CanvasGroup", {
        Name = "EZRAGOX_TopToast",
        AnchorPoint = Vector2.new(0.5, 1),
        Position = UDim2.new(0, panelPos.X + panelSize.X / 2, 0, math.max(panelPos.Y + 6, 74)),
        Size = UDim2.new(0, width or 300, 0, 42),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        GroupTransparency = 1,
        ZIndex = 600,
    }, ScreenGui)
    activeTopToast = toast
    corner(toast, 12)
    local topToastBg = new("Frame", {
        Name = "TopToastBackground",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.fromRGB(23, 11, 16),
        BorderSizePixel = 0,
        ZIndex = 600,
    }, toast)
    corner(topToastBg, 12)
    new("UIGradient", {
        Rotation = 0,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(43, 13, 21)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(23, 11, 16)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(13, 9, 13)),
        }),
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.05),
            NumberSequenceKeypoint.new(1, 0.3),
        }),
        ZIndex = 600,
    }, topToastBg)
    local glowStroke = stroke(toast, 1.5, Color3.fromRGB(255, 45, 65), 0.1)
    local topBar = new("Frame", {
        Size = UDim2.new(0, 4, 1, 0), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 601,
    }, toast)
    local topBarGrad = new("UIGradient", {Rotation = 90}, topBar)
    topBarGrad.Color = notifFlowSeq(math.random() * 5, 0.5)
    new("TextLabel", {
        Size = UDim2.new(1, -24, 1, 0),
        Position = UDim2.new(0, 16, 0, 0),
        BackgroundTransparency = 1,
        Text = text,
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextTransparency = 0,
        TextStrokeTransparency = 1,
        RichText = false,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 602,
    }, toast)
    local scale = new("UIScale", {Scale = 0.88}, toast)

    -- Performans: her karede Lua calistirmak yerine motor tarafinda dongulu tween kullanilir
    glowStroke.Transparency = 0.0
    TweenService:Create(glowStroke, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {Transparency = 0.3}):Play()

    local rest = toast.Position
    toast.Position = rest + UDim2.new(0, 0, 0, 10)
    tween(toast, 0.26, {GroupTransparency = 0, Position = rest})
    tween(scale, 0.3, {Scale = 1}, Enum.EasingStyle.Back)
    task.delay(duration or 2.5, function()
        if toast.Parent then
            tween(toast, 0.3, {GroupTransparency = 1})
            tween(scale, 0.3, {Scale = 0.9})
            task.delay(0.35, function() toast:Destroy() end)
        end
    end)
end
end

---------------------------------------------------------
-- 5. BİLEŞENLER
---------------------------------------------------------
local orders = {}
local function nextOrder(page)
    orders[page] = (orders[page] or 0) + 1
    return orders[page]
end

local function createSection(page, text)
    -- Fotoğraftaki düzen: başlık satırı (ikon kutusu + büyük harf başlık), altında sıkı ve eşit aralıklı satırlar.
    -- Önceki gruptan ayırmak için başlığın üstünde boşluk bırakılır (sayfadaki ilk başlıkta yok).
    local first = (orders[page] or 0) == 0
    local gap = first and 0 or 12
    local holder = new("Frame", {
        LayoutOrder = nextOrder(page),
        Size = UDim2.new(1, 0, 0, gap + 28),
        BackgroundTransparency = 1,
        ZIndex = 3,
    }, page)

    local bar = new("Frame", {
        Position = UDim2.new(0, 0, 0, gap),
        Size = UDim2.new(1, 0, 0, 28),
        BackgroundColor3 = Color3.fromRGB(34, 13, 20),
        BackgroundTransparency = 0.12,
        BorderSizePixel = 0,
        ZIndex = 3,
    }, holder)
    corner(bar, 12)
    stroke(bar, 1, Color3.fromRGB(105, 28, 42), 0.4)

    local iconBox = new("Frame", {
        Position = UDim2.new(0, 8, 0.5, -10),
        Size = UDim2.new(0, 20, 0, 20),
        BackgroundColor3 = Color3.fromRGB(255, 42, 60),
        BackgroundTransparency = 0.78,
        BorderSizePixel = 0,
        ZIndex = 4,
    }, bar)
    corner(iconBox, 6)
    local glow = stroke(iconBox, 1, Color3.fromRGB(255, 60, 75), 0.55)
    local dot = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.new(0, 6, 0, 6),
        BackgroundColor3 = Color3.fromRGB(255, 70, 82),
        BorderSizePixel = 0,
        ZIndex = 5,
    }, iconBox)
    pill(dot)

    -- Not: arama sistemi başlığı holder'ın doğrudan çocuğu olan TextLabel'dan okuyor; o yüzden label burada kalmalı.
    local label = new("TextLabel", {
        Position = UDim2.new(0, 38, 0, gap),
        Size = UDim2.new(1, -48, 0, 28),
        BackgroundTransparency = 1,
        Text = string.upper(text),
        Font = Enum.Font.GothamBlack,
        TextSize = 11,
        TextColor3 = Color3.fromRGB(255, 112, 122),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 5,
    }, holder)
    local headingGradient = new("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(155, 15, 32)),
            ColorSequenceKeypoint.new(0.48, Color3.fromRGB(255, 70, 82)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 165, 145)),
        }),
        Rotation = 0,
    }, label)
    regFlow(UIFlows, headingGradient, 0.2, 0.75, 42)
    Pulsers[#Pulsers + 1] = {
        obj = glow, prop = "Transparency", base = 0.4, amp = 0.35, speed = 4.2,
    }
    -- Kırmızı nokta yanıp söner (sönükken neredeyse kaybolur), ikon kutusu da onunla birlikte nabız atar
    Pulsers[#Pulsers + 1] = {
        obj = dot, prop = "BackgroundTransparency", base = 0.45, amp = 0.45, speed = 4.2,
    }
    Pulsers[#Pulsers + 1] = {
        obj = iconBox, prop = "BackgroundTransparency", base = 0.7, amp = 0.2, speed = 4.2,
    }
    return holder
end

local ROW_BG = Color3.fromRGB(20, 12, 16)
local ROW_BG_HOVER = Color3.fromRGB(48, 12, 22)
local ROW_STROKE = Color3.fromRGB(105, 28, 42)

local function baseRow(page, class, height)
    local row = new(class, {
        LayoutOrder = nextOrder(page),
        Size = UDim2.new(1, 0, 0, height),
        BackgroundColor3 = ROW_BG,
        BackgroundTransparency = 0.05,
        BorderSizePixel = 0,
        ZIndex = 3,
    }, page)
    if class == "TextButton" then
        row.AutoButtonColor = false
        setText(row, "")
    end
    corner(row, 12)
    local rowGradient = new("UIGradient", {
        Rotation = 0,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(43, 13, 21)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(23, 11, 16)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(13, 9, 13)),
        }),
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.2),
            NumberSequenceKeypoint.new(1, 0.48),
        }),
    }, row)
    local st = stroke(row, 1, ROW_STROKE, 0.32)
    return row, st
end

local function rowLabel(row, text)
    return new("TextLabel", {
        Size = UDim2.new(1, -70, 0, 20),
        Position = UDim2.new(0, 14, 0, 11),
        BackgroundTransparency = 1,
        Text = text,
        Font = Enum.Font.GothamMedium,
        TextSize = 14,
        TextColor3 = Color3.fromRGB(228, 233, 245),
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 4,
    }, row)
end

local function hoverFx(row, st)
    ctaFx(row, {stroke = st, radius = 12, hoverBg = ROW_BG_HOVER, pressBg = Color3.fromRGB(62, 18, 36)})
end

local function createButton(page, text, callback)
    local btn, st = baseRow(page, "TextButton", 42)
    local lbl = rowLabel(btn, text)
    lbl.Position = UDim2.new(0, 14, 0, 11)
    new("TextLabel", {
        Size = UDim2.new(0, 30, 1, 0), Position = UDim2.new(1, -36, 0, 0), BackgroundTransparency = 1,
        Text = "›", Font = Enum.Font.GothamBold, TextSize = 22, TextColor3 = Color3.fromRGB(120, 134, 170), ZIndex = 4,
    }, btn)
    hoverFx(btn, st)
    bind(btn.MouseButton1Click, function()
        playClickSound()
        if callback then pcall(callback) end
        -- Button callbacks often change a selected option or preference.
        saveConfig()
    end)
    return btn
end

local function createToggle(page, text, default, callback, restoreOnLoad)
    local savedState = Settings.ToggleStates[text]
    local state = default and true or false
    if savedState ~= nil then state = (savedState == true) end
    local row, st = baseRow(page, "TextButton", 42)
    local label = rowLabel(row, text)
    label.Size = UDim2.new(1, -104, 0, 20)

    -- Geniş, cam/neon geçişli premium anahtar.
    local trackF = new("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -12, 0.5, 0),
        Size = UDim2.new(0, 48, 0, 24),
        BackgroundColor3 = Color3.fromRGB(38, 17, 23),
        BorderSizePixel = 0,
        ClipsDescendants = true,
        ZIndex = 4,
    }, row)
    pill(trackF)
    local trackStroke = stroke(trackF, 1, Color3.fromRGB(130, 55, 65), 0.45)
    local onFill = new("Frame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BackgroundTransparency = state and 0 or 1,
        BorderSizePixel = 0,
        ZIndex = 5,
    }, trackF)
    pill(onFill)
    local onGradient = new("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(95, 5, 18)),
            ColorSequenceKeypoint.new(0.52, Color3.fromRGB(255, 28, 48)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 105, 55)),
        }),
        Rotation = 0,
    }, onFill)
    regFlow(UIFlows, onGradient, 0.15, 0.72, 58)

    local knob = new("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, state and 27 or 3, 0.5, 0),
        Size = UDim2.new(0, 18, 0, 18),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
        ZIndex = 6,
    }, trackF)
    pill(knob)
    local knobStroke = stroke(knob, 1, Color3.fromRGB(255, 210, 210), 0.28)
    Pulsers[#Pulsers + 1] = {
        obj = trackStroke, prop = "Transparency", base = 0.28, amp = 0.13, speed = 2.8,
    }

    hoverFx(row, st)

    local obj = {}
    obj.Key = text
    function obj.Set(v, silent, skipSave)
        state = v and true or false
        if not skipSave then Settings.ToggleStates[text] = state end
        tween(onFill, 0.24, {BackgroundTransparency = state and 0 or 1}, Enum.EasingStyle.Quad)
        tween(knob, 0.28, {Position = UDim2.new(0, state and 27 or 3, 0.5, 0)}, Enum.EasingStyle.Quint)
        tween(trackStroke, 0.28, {
            Transparency = state and 0.12 or 0.55,
            Color = state and Color3.fromRGB(255, 45, 65) or Color3.fromRGB(105, 65, 72),
        }, Enum.EasingStyle.Quint)
        tween(knobStroke, 0.22, {
            Transparency = state and 0.05 or 0.28,
            Color = state and Color3.fromRGB(255, 110, 115) or Color3.fromRGB(255, 210, 210),
        }, Enum.EasingStyle.Quad)
        if not silent and callback then pcall(callback, state) end
        if not skipSave then saveConfig() end
    end
    bind(row.MouseButton1Click, function()
        playClickSound()
        obj.Set(not state)
    end)
    if restoreOnLoad ~= false and savedState == true and callback then
        task.defer(function()
            if alive then
                suppressNotify = true
                pcall(callback, true)
                suppressNotify = false
            end
        end)
    end
    return obj
end

local function createSlider(page, text, min, max, default, callback, suffix)
    local savedValue = Settings.SliderValues[text]
    local value = (type(savedValue) == "number") and math.clamp(savedValue, min, max) or default
    local row = baseRow(page, "Frame", 44)
    local sliderLabel = rowLabel(row, text)
    sliderLabel.Position = UDim2.new(0, 14, 0.5, -10)
    sliderLabel.Size = UDim2.new(0.4, -14, 0, 20)
    sliderLabel.TextTruncate = Enum.TextTruncate.AtEnd
    local valueLabel = new("TextLabel", {
        Size = UDim2.new(0, 48, 0, 26), Position = UDim2.new(1, -60, 0.5, -13),
        BackgroundColor3 = Color3.fromRGB(12, 7, 10), BackgroundTransparency = 0.1, BorderSizePixel = 0,
        Text = "", Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = Color3.fromRGB(255, 65, 75),
        TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 4,
    }, row)
    corner(valueLabel, 8)
    stroke(valueLabel, 1, Color3.fromRGB(105, 28, 42), 0.35)
    local hit = new("TextButton", {
        Size = UDim2.new(0.6, -76, 0, 24), Position = UDim2.new(0.4, 0, 0.5, -12),
        BackgroundTransparency = 1, Text = "", ZIndex = 5,
    }, row)
    local trackF = new("Frame", {
        AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.new(1, 0, 0, 6),
        BackgroundColor3 = Color3.fromRGB(55, 20, 28), BorderSizePixel = 0, ZIndex = 5,
    }, hit)
    pill(trackF)
    local fill = new("Frame", {Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 6}, trackF)
    pill(fill)
    regFlow(UIFlows, new("UIGradient", {}, fill), 0, 0.7)
    local knob = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.new(0, 14, 0, 14),
        BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 7,
    }, trackF)
    pill(knob)

    local function render()
        local ratio = (value - min) / (max - min)
        fill.Size = UDim2.new(ratio, 0, 1, 0)
        knob.Position = UDim2.new(ratio, 0, 0.5, 0)
        setText(valueLabel, tostring(value) .. (suffix or ""))
    end
    render()
    -- Dışarıdan değer verebilmek için ayarlayıcı
    Settings.SliderSetters = Settings.SliderSetters or {}
    Settings.SliderSetters[text] = function(v, silent)
        v = math.clamp(math.floor((tonumber(v) or 0) + 0.5), min, max)
        value = v
        Settings.SliderValues[text] = v
        render()
        if not silent and callback then pcall(callback, v) end
        saveConfig()
    end

    local dragging = false
    local function setFromX(x)
        local ratio = math.clamp((x - trackF.AbsolutePosition.X) / math.max(trackF.AbsoluteSize.X, 1), 0, 1)
        local v = math.floor(min + (max - min) * ratio + 0.5)
        if v ~= value then
            value = v
            Settings.SliderValues[text] = value
            render()
            if callback then pcall(callback, value) end
            saveConfig()
        end
    end
    bind(hit.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            page.ScrollingEnabled = false
            setFromX(input.Position.X)
        end
    end)
    bind(UserInputService.InputChanged, function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            setFromX(input.Position.X)
        end
    end)
    bind(UserInputService.InputEnded, function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
            dragging = false
            page.ScrollingEnabled = true
        end
    end)
    Settings.SliderValues[text] = value
    if savedValue ~= nil and callback then
        task.defer(function()
            if alive then
                suppressNotify = true
                pcall(callback, value)
                suppressNotify = false
            end
        end)
    end
    return row
end

---------------------------------------------------------
-- 6. KENAR ÇUBUĞU + İÇERİK ALANI
---------------------------------------------------------
local Sidebar = new("Frame", {
    Position = UDim2.new(0, 14, 0, 90), Size = UDim2.new(0, 154, 1, -104),
    BackgroundColor3 = Color3.fromRGB(9, 7, 10), BackgroundTransparency = 0.04,
    BorderSizePixel = 0, ZIndex = 2,
}, MainFrame)
corner(Sidebar, 16)
local SidebarStroke = stroke(Sidebar, 1, Color3.fromRGB(135, 28, 42), 0.38)
regFlow(UIFlows, new("UIGradient", {}, SidebarStroke), 1, 0.8, 24)
local SideTopGlow = new("Frame", {
    Position = UDim2.new(0, 12, 0, 0), Size = UDim2.new(1, -24, 0, 2),
    BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 3,
}, Sidebar)
regFlow(UIFlows, new("UIGradient", {}, SideTopGlow), 0, 0.7)
local TabList = new("ScrollingFrame", {
    Position = UDim2.new(0, 9, 0, 12), Size = UDim2.new(1, -18, 1, -104), BackgroundTransparency = 1, BorderSizePixel = 0,
    ClipsDescendants = true, ScrollBarThickness = 2, ScrollBarImageColor3 = Color3.fromRGB(220, 42, 58),
    CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y, ZIndex = 3,
}, Sidebar)
new("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6)}, TabList)
new("UIPadding", {PaddingLeft = UDim.new(0, 3), PaddingRight = UDim.new(0, 5), PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 2)}, TabList)

-- Yapımcı yazısı + fotoğraf + mavi tik (hareketli yazı, kırmızı aura)
do
local CREATOR_IMAGE_ID = 89633137402865
local TextService = game:GetService("TextService")

local CreatorContainer = new("Frame", {
    AnchorPoint = Vector2.new(0, 1),
    Position = UDim2.new(0, 8, 1, -34),
    Size = UDim2.new(1, -16, 0, 48),
    BackgroundTransparency = 1,
    ZIndex = 3,
}, Sidebar)

local CreatorPhoto = new("ImageLabel", {
    Size = UDim2.new(0, 42, 0, 42),
    Position = UDim2.new(0, 0, 0.5, 0),
    AnchorPoint = Vector2.new(0, 0.5),
    BackgroundColor3 = Color3.fromRGB(24, 30, 46),
    Image = CREATOR_IMAGE_ID ~= 0 and ("rbxassetid://" .. CREATOR_IMAGE_ID) or "",
    ScaleType = Enum.ScaleType.Crop,
    ZIndex = 4,
}, CreatorContainer)
pill(CreatorPhoto)
local CreatorPhotoStroke = stroke(CreatorPhoto, 2, Color3.fromRGB(255, 50, 60))
Pulsers[#Pulsers + 1] = {obj = CreatorPhotoStroke, prop = "Transparency", base = 0.3, amp = 0.25, speed = 3}

-- hasan_usta0 kullanıcısının Roblox avatar fotoğrafı (başarısız olursa yukarıdaki ID kalır)
task.spawn(function()
    local ok, userId = pcall(function()
        return Players:GetUserIdFromNameAsync("hasan_usta0")
    end)
    if ok and userId then
        local ok2, content = pcall(function()
            return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
        end)
        if ok2 and content and content ~= "" then
            CreatorPhoto.Image = content
        end
    end
end)

new("TextLabel", {
    Position = UDim2.new(0, 48, 0, 3),
    Size = UDim2.new(1, -48, 0, 12),
    BackgroundTransparency = 1,
    Text = "Yapımcı:",
    Font = Enum.Font.GothamMedium,
    TextSize = 9,
    TextColor3 = Color3.fromRGB(130, 145, 175),
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 3,
}, CreatorContainer)

-- Harf harf hareketli isim
local NAME_TEXT, NAME_SIZE = "Hasan Usta", 12
local NameHolder = new("Frame", {
    Position = UDim2.new(0, 48, 0, 18),
    Size = UDim2.new(0, 10, 0, 18),
    BackgroundTransparency = 1,
    ZIndex = 4,
}, CreatorContainer)

local nameLetters = {}
local nameW = 0
do
    local idx = 0
    for _, cp in utf8.codes(NAME_TEXT) do
        local ch = utf8.char(cp)
        local ok, size = pcall(function()
            return TextService:GetTextSize(ch, NAME_SIZE, Enum.Font.GothamBlack, Vector2.new(200, 50))
        end)
        local w = (ok and size.X) or 8
        if ch ~= " " then
            local lbl = new("TextLabel", {
                Position = UDim2.new(0, nameW, 0, 0),
                Size = UDim2.new(0, w, 1, 0),
                BackgroundTransparency = 1,
                Text = ch,
                Font = Enum.Font.GothamBlack,
                TextSize = NAME_SIZE,
                TextColor3 = Color3.fromRGB(255, 50, 60),
                ZIndex = 5,
            }, NameHolder)
            -- Harflerin çevresindeki kırmızı kontur kaldırıldı.
            nameLetters[#nameLetters + 1] = {
                lbl = lbl,
                i = idx,
                x = nameW,
                currentY = 0,
                currentColor = Color3.fromRGB(255, 50, 60),
            }
        end
        nameW = nameW + w
        idx = idx + 1
    end
end
NameHolder.Size = UDim2.new(0, nameW, 0, 18)

-- Yazının çevresindeki kırmızı çerçeve/aura kaldırıldı.
-- NameHolder ve harf etiketleri arka plansız kalır.
NameHolder.BackgroundTransparency = 1

-- Mavi tik yerine kullanıcının verdiği özel rozet görseli
local VerifiedBadge = new("ImageLabel", {
    Position = UDim2.new(0, nameW + 5, 0, 1),
    Size = UDim2.new(0, 17, 0, 17),
    BackgroundTransparency = 1,
    Image = "rbxassetid://100936935753681",
    ScaleType = Enum.ScaleType.Fit,
    ZIndex = 6,
}, NameHolder)

-- Hasan Usta yazısı: takılma hissini azaltan yumuşak, sürekli harf dalgası.
local RED_A, RED_B = Color3.fromRGB(225, 55, 65), Color3.fromRGB(255, 125, 125)
local NAME_WAVE_SPEED = 3.0
local NAME_WAVE_SPACING = 0.43
local NAME_WAVE_HEIGHT = 1.65
local NAME_SMOOTHNESS = 13

local nameWaveAcc = 0
bind(RunService.RenderStepped, function(dt)
    if not menuOpen then return end
    nameWaveAcc = nameWaveAcc + dt
    if nameWaveAcc < 1 / 30 then return end
    dt = nameWaveAcc
    nameWaveAcc = 0
    local t = os.clock()
    -- Kare hızından bağımsız üstel yumuşatma; ani konum sıçramalarını engeller.
    local alpha = 1 - math.exp(-NAME_SMOOTHNESS * math.min(dt, 0.05))
    for _, L in ipairs(nameLetters) do
        local targetY = math.sin(t * NAME_WAVE_SPEED - L.i * NAME_WAVE_SPACING) * NAME_WAVE_HEIGHT
        L.currentY = L.currentY + (targetY - L.currentY) * alpha
        L.lbl.Position = UDim2.new(0, L.x, 0, L.currentY)

        local colorPhase = (math.sin(t * 1.8 - L.i * 0.34) + 1) * 0.5
        local targetColor = RED_A:Lerp(RED_B, colorPhase * 0.48)
        L.currentColor = L.currentColor:Lerp(targetColor, alpha)
        L.lbl.TextColor3 = L.currentColor
    end
end)

-- Yazıdan yukarı doğru saçılan kırmızı aura parçacıkları
task.spawn(function()
    while alive do
        task.wait(0.2)
        if menuOpen and MainFrame.Visible then
            local sz = math.random(2, 4)
            local px = math.random(0, math.max(1, math.floor(nameW)))
            local p = new("Frame", {
                Size = UDim2.new(0, sz, 0, sz),
                Position = UDim2.new(0, px, 0, 8),
                BackgroundColor3 = Color3.fromRGB(205, math.random(35, 65), math.random(45, 70)),
                BackgroundTransparency = 0.55,
                BorderSizePixel = 0,
                ZIndex = 3,
            }, NameHolder)
            pill(p)
            local dur = math.random(8, 15) / 10
            tween(p, dur, {
                Position = UDim2.new(0, px + math.random(-8, 8), 0, -16 - math.random(0, 10)),
                BackgroundTransparency = 1,
                Size = UDim2.new(0, 0, 0, 0),
            }, Enum.EasingStyle.Sine)
            task.delay(dur, function() p:Destroy() end)
        end
    end
end)

end

local SidebarKeyHint = new("TextLabel", {
    AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 8, 1, -4), Size = UDim2.new(1, -16, 0, 22),
    BackgroundTransparency = 1, Text = Settings.ToggleKey.Name .. "  •  menüyü aç / kapat", Font = Enum.Font.GothamMedium,
    TextSize = 10, TextColor3 = Color3.fromRGB(100, 112, 145), TextWrapped = true, ZIndex = 3,
}, Sidebar)

local Content = new("Frame", {
    Position = UDim2.new(0, 180, 0, 90), Size = UDim2.new(1, -194, 1, -104),
    BackgroundColor3 = Color3.fromRGB(9, 13, 25), BackgroundTransparency = 0.18,
    ClipsDescendants = true, BorderSizePixel = 0, ZIndex = 2,
}, MainFrame)
corner(Content, 16)
local ContentStroke = stroke(Content, 1, Color3.fromRGB(55, 70, 105), 0.58)
regFlow(UIFlows, new("UIGradient", {}, ContentStroke), 2, 0.85, -20)
local ContentTopLine = new("Frame", {
    Position = UDim2.new(0, 16, 0, 0), Size = UDim2.new(1, -32, 0, 2),
    BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 4,
}, Content)
regFlow(UIFlows, new("UIGradient", {}, ContentTopLine), 1, 0.7, 28)

Settings.SRCH = {PAGE_Y = 49}            -- arama çubuğu durumu (yeni local açmamak için Settings içinde)
local function createPage()
    local page = new("ScrollingFrame", {
        Position = UDim2.new(0, 0, 0, Settings.SRCH.PAGE_Y),
        Size = UDim2.new(1, 0, 1, -(Settings.SRCH.PAGE_Y + 5)),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = Color3.fromRGB(220, 42, 58),
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        Visible = false,
        ZIndex = 3,
    }, Content)
    new("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 3)}, page) -- satırlar arası eşit ince aralık
    -- Tüm sekmelerde içerikleri yatayda eşit iç boşlukla hizala.
    -- Önceden yalnızca sağ boşluk vardı; sol kart kenarı çerçeveye yapışıyordu.
    new("UIPadding", {
        PaddingLeft = UDim.new(0, 10),
        PaddingRight = UDim.new(0, 10),
        PaddingTop = UDim.new(0, 8),
        PaddingBottom = UDim.new(0, 10),
    }, page)
    return page
end

local Tabs, currentTab = {}, nil
local TAB_OFF = Color3.fromRGB(154, 143, 148)
local TAB_RED = Color3.fromRGB(255, 48, 65)

local function selectTab(tab)
    if Settings.SRCH.clear then Settings.SRCH.clear() end
    if currentTab == tab then return end
    currentTab = tab
    fxResetAll(true)
    for _, t in ipairs(Tabs) do
        local on = (t == tab)
        tween(t.btn, 0.22, {
            BackgroundTransparency = on and 0.04 or 1,
            BackgroundColor3 = on and Color3.fromRGB(67, 12, 23) or Color3.fromRGB(20, 10, 14),
        })
        tween(t.label, 0.2, {
            TextColor3 = on and Color3.fromRGB(255, 246, 246) or TAB_OFF,
            TextSize = on and 13 or 12,
        })
        tween(t.iconPlate, 0.22, {
            BackgroundColor3 = on and Color3.fromRGB(190, 18, 42) or Color3.fromRGB(65, 8, 20),
            BackgroundTransparency = on and 0.02 or 0.18,
        })
        if t.iconPlateStroke then
            tween(t.iconPlateStroke, 0.22, {
                Color = on and Color3.fromRGB(255, 115, 125) or Color3.fromRGB(255, 55, 72),
                Transparency = on and 0.12 or 0.34,
            })
        end
        tween(t.iconLabel, 0.22, {
            TextColor3 = on and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(225, 105, 115),
            TextTransparency = on and 0 or 0.12,
        })
        tween(t.ind, 0.25, {Size = UDim2.new(0, 4, 0, on and 27 or 0)}, Enum.EasingStyle.Back)
        tween(t.stroke, 0.22, {
            Transparency = on and 0.22 or 0.78,
            Color = on and Color3.fromRGB(255, 54, 72) or Color3.fromRGB(110, 35, 48),
        })
        if on then
            t.page.Position = UDim2.new(0, 0, 0, Settings.SRCH.PAGE_Y + 10)
            t.page.Visible = true
            t.page.ScrollBarImageTransparency = 0.45
            tween(t.page, 0.34, {
                Position = UDim2.new(0, 0, 0, Settings.SRCH.PAGE_Y),
                ScrollBarImageTransparency = 0,
            }, Enum.EasingStyle.Quint)
        else
            t.page.Visible = false
        end
    end
end

local function createTab(name, icon)
    local page = createPage()
    local btn = new("TextButton", {
        LayoutOrder = #Tabs + 1,
        Size = UDim2.new(1, 0, 0, 42),
        BackgroundColor3 = Color3.fromRGB(20, 10, 14),
        BackgroundTransparency = 1,
        AutoButtonColor = false,
        Text = "",
        ZIndex = 3,
    }, TabList)
    corner(btn, 13)

    local btnStroke = stroke(btn, 1, Color3.fromRGB(110, 35, 48), 0.78)
    new("UIGradient", {
        Rotation = 0,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(72, 12, 25)),
            ColorSequenceKeypoint.new(0.55, Color3.fromRGB(39, 10, 17)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(22, 9, 14)),
        }),
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.12),
            NumberSequenceKeypoint.new(1, 0.48),
        }),
    }, btn)

    local ind = new("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.new(0, 4, 0, 0),
        BackgroundColor3 = TAB_RED,
        BorderSizePixel = 0,
        ZIndex = 5,
    }, btn)
    pill(ind)
    local indGlow = stroke(ind, 3, Color3.fromRGB(255, 35, 58), 0.45)

    local iconPlate = new("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 10, 0.5, 0),
        Size = UDim2.new(0, 29, 0, 29),
        BackgroundColor3 = Color3.fromRGB(35, 15, 21),
        BackgroundTransparency = 0.38,
        BorderSizePixel = 0,
        ZIndex = 4,
    }, btn)
    corner(iconPlate, 99)
    local iconPlateStroke = stroke(iconPlate, 1, Color3.fromRGB(255, 55, 72), 0.34)
    local iconPlateGradient = new("UIGradient", {
        Rotation = 35,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(75, 5, 18)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(185, 15, 38)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(45, 7, 15)),
        }),
    }, iconPlate)
    regFlow(UIFlows, iconPlateGradient, 0.18, 0.82, 24)
    Pulsers[#Pulsers + 1] = {
        obj = iconPlateStroke, prop = "Transparency",
        base = 0.34, amp = 0.18, speed = 2.4,
    }

    local iconLabel = new("TextLabel", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = icon,
        Font = Enum.Font.GothamBold,
        TextSize = 15,
        TextColor3 = Color3.fromRGB(225, 105, 115),
        ZIndex = 5,
    }, iconPlate)

    -- Sekme simgeleri ana sayfadaki gibi tek renkli, sade ve net karakterlerdir.
    -- Özellikler: ✦ yıldız, Ayarlar: ☰ liste; Ana Sayfa ⌂ ile aynı sade, tek renkli stil.
    iconLabel.TextColor3 = Color3.fromRGB(255, 75, 85)
    iconLabel.TextSize = (name == "Troll") and 19 or 17

    -- Özellikler ve Ayarlar simgeleri yazı tipinde kutu çıktığı için çizgi çizgi
    -- (UI parçalarıyla) çizilir: Özellikler = parıltı, Ayarlar = dişli.
    local drawnKind = (name == "Özellikler" and "sparkle") or (name == "Ayarlar" and "gear")
        or (name == "Premium" and "crown") or (name == "Yönetim" and "lock") or nil
    if drawnKind then
        setText(iconLabel, "")
        local holder = new("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, 0, 0.5, 0),
            Size = UDim2.new(0, 20, 0, 20),
            BackgroundTransparency = 1,
            ZIndex = 5,
        }, iconPlate)
        local fills, strokes = {}, {}
        local function bar(w, h, x, y, rot)
            local f = new("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(0.5, x, 0.5, y),
                Size = UDim2.new(0, w, 0, h),
                Rotation = rot or 0,
                BackgroundColor3 = iconLabel.TextColor3,
                BorderSizePixel = 0,
                ZIndex = 5,
            }, holder)
            fills[#fills + 1] = f
            return f
        end
        if drawnKind == "sparkle" then
            bar(2, 17, 0, 0, 0)
            bar(17, 2, 0, 0, 0)
            bar(2, 12, 0, 0, 45)
            bar(2, 12, 0, 0, -45)
        elseif drawnKind == "crown" then
            bar(14, 3, 0, 6, 0)
            bar(2, 11, -5, 0, -16)
            bar(2, 13, 0, -1, 0)
            bar(2, 11, 5, 0, 16)
            for _, d in ipairs({{-7, -6}, {0, -8}, {7, -6}}) do
                pill(bar(4, 4, d[1], d[2], 0))
            end
        elseif drawnKind == "lock" then
            local shackle = new("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(0.5, 0, 0.5, -4),
                Size = UDim2.new(0, 10, 0, 10),
                BackgroundTransparency = 1,
                ZIndex = 5,
            }, holder)
            pill(shackle)
            strokes[#strokes + 1] = stroke(shackle, 2, iconLabel.TextColor3, 0)
            corner(bar(14, 9, 0, 4, 0), 2)
        else
            local ring = new("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(0.5, 0, 0.5, 0),
                Size = UDim2.new(0, 12, 0, 12),
                BackgroundTransparency = 1,
                ZIndex = 5,
            }, holder)
            pill(ring)
            strokes[#strokes + 1] = stroke(ring, 2, iconLabel.TextColor3, 0)
            for i = 0, 7 do
                local a = math.rad(i * 45)
                bar(4, 3, math.cos(a) * 8, math.sin(a) * 8, i * 45)
            end
        end
        local function syncDrawnIcon()
            for _, f in ipairs(fills) do
                f.BackgroundColor3 = iconLabel.TextColor3
                f.BackgroundTransparency = iconLabel.TextTransparency
            end
            for _, st in ipairs(strokes) do
                st.Color = iconLabel.TextColor3
                st.Transparency = iconLabel.TextTransparency
            end
        end
        iconLabel:GetPropertyChangedSignal("TextColor3"):Connect(syncDrawnIcon)
        iconLabel:GetPropertyChangedSignal("TextTransparency"):Connect(syncDrawnIcon)
    end


    local label = new("TextLabel", {
        Size = UDim2.new(1, -54, 1, 0),
        Position = UDim2.new(0, 48, 0, 0),
        BackgroundTransparency = 1,
        Text = name,
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        TextColor3 = TAB_OFF,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 4,
    }, btn)

    local tab = {
        btn = btn, label = label, iconPlate = iconPlate,
        iconLabel = iconLabel, iconPlateStroke = iconPlateStroke,
        ind = ind, stroke = btnStroke, page = page, name = name,
    }
    Tabs[#Tabs + 1] = tab
    local tabScale = new("UIScale", {Scale = 1}, btn)
    -- Ortak buton efekti (renkleri sekme kendi seçili/seçilmemiş mantığıyla yönetir)
    ctaFx(btn, {radius = 13, colors = false, scale = tabScale, persist = true})

    bind(btn.MouseEnter, function()
        if currentTab ~= tab then
            tween(btn, 0.16, {BackgroundTransparency = 0.55, BackgroundColor3 = Color3.fromRGB(48, 12, 22)})
            tween(iconPlate, 0.16, {BackgroundTransparency = 0.12})
        end
    end)
    bind(btn.MouseLeave, function()
        if currentTab ~= tab then
            tween(btn, 0.16, {BackgroundTransparency = 1})
            tween(iconPlate, 0.16, {BackgroundTransparency = 0.38})
        end
    end)
    bind(btn.MouseButton1Click, function()
        playClickSound()
        selectTab(tab)
    end)
    return page, tab
end

---------------------------------------------------------
-- GENEL ARAMA ÇUBUĞU
-- Yazdığın kelimeyi TÜM sekmelerdeki özelliklerde (satır, bölüm ve sekme adı) arar.
-- Bulunan satırlar sonuç sayfasında gerçek haliyle (açılıp kapanır, ayarlanır) gösterilir;
-- arama temizlenince her satır kendi sekmesine ve yerine geri döner.
---------------------------------------------------------
EN_TEXT["Özellik ara...  (örn: uçuş, hız, kill)"] = "Search features...  (e.g. fly, speed, kill)"
EN_TEXT["FLING  •  İSİM YAZ / TIKLA / DOKUN"] = "FLING  •  TYPE NAME / CLICK / TOUCH"
EN_TEXT["Sonuç bulunamadı"] = "No results found"
EN_TEXT["Farklı bir kelime dene."] = "Try a different keyword."

-- Kendi fonksiyonunun içinde çalışır: ana bölümdeki 200 local sınırına takılmaz.
;(function()
    local SearchPage = createPage()
    local SearchBox
    local SearchBar = new("Frame", {
        Position = UDim2.new(0, 10, 0, 8), Size = UDim2.new(1, -20, 0, 32),
        BackgroundColor3 = ROW_BG, BackgroundTransparency = 0.05,
        BorderSizePixel = 0, ZIndex = 6,
    }, Content)
    corner(SearchBar, 12)
    local SearchStroke = stroke(SearchBar, 1, ROW_STROKE, 0.32)

    new("TextLabel", {
        Position = UDim2.new(0, 6, 0, 0), Size = UDim2.new(0, 28, 1, 0),
        BackgroundTransparency = 1, Text = "🔍", Font = Enum.Font.GothamBold,
        TextSize = 14, TextColor3 = Color3.fromRGB(255, 90, 100), ZIndex = 7,
    }, SearchBar)

    SearchBox = new("TextBox", {
        Position = UDim2.new(0, 34, 0, 0), Size = UDim2.new(1, -70, 1, 0),
        BackgroundTransparency = 1,
        PlaceholderText = "Özellik ara...  (örn: uçuş, hız, kill)",
        PlaceholderColor3 = Color3.fromRGB(125, 108, 116),
        Font = Enum.Font.GothamMedium, TextSize = 13,
        TextColor3 = Color3.fromRGB(235, 238, 248),
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false, ZIndex = 7,
    }, SearchBar)
    SearchBox.Text = ""

    local ClearBtn = new("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0),
        Size = UDim2.new(0, 22, 0, 22), BackgroundColor3 = Color3.fromRGB(65, 12, 24),
        BackgroundTransparency = 0.2, AutoButtonColor = false,
        Text = "✕", Font = Enum.Font.GothamBold, TextSize = 11,
        TextColor3 = Color3.fromRGB(255, 130, 140), Visible = false, ZIndex = 8,
    }, SearchBar)
    corner(ClearBtn, 99)
    ClearBtn.Text = "✕"

    -- Türkçe karakterleri sadeleştir (İ/ı/Ş/Ğ/Ü/Ö/Ç) ki "kilic" ile "Kılıç" bulunsun
    local TR_MAP = {
        ["İ"] = "i", ["I"] = "i", ["ı"] = "i", ["Ş"] = "s", ["ş"] = "s",
        ["Ğ"] = "g", ["ğ"] = "g", ["Ü"] = "u", ["ü"] = "u",
        ["Ö"] = "o", ["ö"] = "o", ["Ç"] = "c", ["ç"] = "c",
    }
    local function norm(s)
        s = tostring(s or "")
        s = s:gsub(utf8.charpattern, function(ch) return TR_MAP[ch] end)
        return (s:lower())
    end

    local SKIP_TABS = {["Ana Sayfa"] = true, ["Yönetim"] = true}

    local function isRow(c)
        if not (c:IsA("Frame") or c:IsA("TextButton")) then return false end
        return c:FindFirstChildOfClass("UICorner") ~= nil
    end

    local function sectionTitle(c)
        if not c:IsA("Frame") or c:FindFirstChildOfClass("UICorner") then return nil end
        local lbl = c:FindFirstChildOfClass("TextLabel")
        if lbl and lbl.Text ~= "" and c.Size.Y.Offset <= 40 then return lbl.Text end
        return nil
    end

    local function rowText(row)
        local parts = {}
        local function add(o)
            if o:IsA("TextLabel") or o:IsA("TextButton") then
                local t = o.Text
                if t and #t > 1 and not (#t <= 8 and t:match("^[%d%.%-%+%%]+%a*%%?$")) then
                    parts[#parts + 1] = t
                end
            end
        end
        add(row)
        for _, d in ipairs(row:GetDescendants()) do add(d) end
        return norm(table.concat(parts, " "))
    end

    local moved, headers = {}, {}
    local searchActive = false

    local NoResults = new("TextLabel", {
        LayoutOrder = 999999, Size = UDim2.new(1, 0, 0, 60), BackgroundTransparency = 1,
        Text = "Sonuç bulunamadı", Font = Enum.Font.GothamBold, TextSize = 14,
        TextColor3 = Color3.fromRGB(190, 150, 158), Visible = false, ZIndex = 4,
    }, SearchPage)

    local function restoreRows()
        for _, m in ipairs(moved) do
            if m.row and m.row.Parent then
                m.row.LayoutOrder = m.order
                m.row.Parent = m.page
            end
        end
        moved = {}
        for _, h in ipairs(headers) do pcall(function() h:Destroy() end) end
        headers = {}
    end

    local function applySearch(query)
        restoreRows()
        local q = norm(query)
        q = (q:gsub("^%s+", ""))
        q = (q:gsub("%s+$", ""))

        if q == "" then
            NoResults.Visible = false
            if searchActive then
                searchActive = false
                SearchPage.Visible = false
                if currentTab then currentTab.page.Visible = true end
            end
            return
        end

        if not searchActive then
            searchActive = true
            if currentTab then currentTab.page.Visible = false end
            SearchPage.Position = UDim2.new(0, 0, 0, Settings.SRCH.PAGE_Y)
            SearchPage.Visible = true
        end
        SearchPage.CanvasPosition = Vector2.new(0, 0)

        local words = {}
        for w in q:gmatch("%S+") do words[#words + 1] = w end
        local function matches(hay)
            for _, w in ipairs(words) do
                if not hay:find(w, 1, true) then return false end
            end
            return true
        end

        local order, count = 0, 0
        for _, tab in ipairs(Tabs) do
            if tab.btn.Visible and not SKIP_TABS[tab.name] then
                local tabNorm = norm(tab.name) .. " " .. norm(tab.label.Text)
                local list = {}
                for _, c in ipairs(tab.page:GetChildren()) do
                    if c:IsA("GuiObject") then list[#list + 1] = c end
                end
                table.sort(list, function(a, b) return a.LayoutOrder < b.LayoutOrder end)

                local sectionNorm, header = "", nil
                for _, c in ipairs(list) do
                    local title = sectionTitle(c)
                    if title then
                        sectionNorm = norm(title)
                    elseif isRow(c) then
                        local hay = tabNorm .. " " .. sectionNorm .. " " .. rowText(c)
                        if matches(hay) then
                            if not header then
                                order = order + 1
                                header = new("TextLabel", {
                                    LayoutOrder = order, Size = UDim2.new(1, 0, 0, 22),
                                    BackgroundTransparency = 1,
                                    Text = "  " .. string.upper(tab.label.Text),
                                    Font = Enum.Font.GothamBlack, TextSize = 10,
                                    TextColor3 = Color3.fromRGB(255, 112, 122),
                                    TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4,
                                }, SearchPage)
                                headers[#headers + 1] = header
                            end
                            order = order + 1
                            count = count + 1
                            moved[#moved + 1] = {row = c, page = tab.page, order = c.LayoutOrder}
                            c.LayoutOrder = order
                            c.Parent = SearchPage
                        end
                    end
                end
            end
        end
        NoResults.LayoutOrder = order + 1
        NoResults.Visible = (count == 0)
    end

    bind(SearchBox:GetPropertyChangedSignal("Text"), function()
        ClearBtn.Visible = SearchBox.Text ~= ""
        applySearch(SearchBox.Text)
    end)
    bind(SearchBox.Focused, function()
        tween(SearchStroke, 0.18, {Color = Color3.fromRGB(255, 54, 72), Transparency = 0.1})
    end)
    bind(SearchBox.FocusLost, function()
        tween(SearchStroke, 0.18, {Color = ROW_STROKE, Transparency = 0.32})
    end)
    bind(ClearBtn.MouseButton1Click, function()
        playClickSound()
        SearchBox.Text = ""
        applySearch("")
    end)

    Settings.SRCH.clear = function()
        if searchActive then
            SearchBox.Text = ""
            applySearch("")
        end
    end
end)()

---------------------------------------------------------
-- SAĞ DIŞ ALANDA TAM BOY KARAKTER + FAREYİ TAKİP EDEN KAFA
---------------------------------------------------------
local MenuCharViewport = new("ViewportFrame", {
    AnchorPoint = Vector2.new(0, 0.5),
    Position = UDim2.new(1, -22, 0.5, 0),
    Size = UDim2.new(0, 340, 1, 120), -- daha uzun: karakter daha büyük görünür
    BackgroundTransparency = 1,
    Ambient = Color3.fromRGB(200, 200, 200),
    LightColor = Color3.new(1, 1, 1),
    Visible = false,
    Active = true, -- ViewportFrame fare/tıklama girdilerini alabilsin
    ZIndex = 15,
}, MainFrame)

local refreshMenuAvatar = nil
do
local menuCharModel, menuCam = nil, nil
local menuCharBasePivot = nil
local headGroup, armGroup = {}, {}
local neckPos, shoulderPos = nil, nil
local menuHrpRot = CFrame.new()
local headYaw, headPitch = 0, 0
local buildSeq = 0
local onAvatarSwapped = nil

-- plr verilmezse kendi karakterim; verilirse o oyuncunun karakteri gösterilir.
local function buildMenuAvatar(plr)
    plr = plr or LocalPlayer
    buildSeq = buildSeq + 1
    local mySeq = buildSeq
    local clone = nil
    local okBuild, errBuild = pcall(function()
        local char = plr.Character
        if char and char:FindFirstChild("HumanoidRootPart") and char:FindFirstChild("Head") then
            local wasArch = char.Archivable
            char.Archivable = true
            clone = char:Clone()
            char.Archivable = wasArch
        end
        -- Karakteri yüklü değilse (uzaktaysa) avatarını Roblox'tan oluştur
        if not clone and plr ~= LocalPlayer then
            local okModel, model = pcall(function()
                return Players:CreateHumanoidModelFromUserId(plr.UserId)
            end)
            if okModel then clone = model end
        end
        if not clone then return end
        -- Bu arada daha yeni bir önizleme istendiyse eskisini bırak
        if mySeq ~= buildSeq then clone:Destroy() return end
        for _, d in ipairs(clone:GetDescendants()) do
            -- Humanoid nesnesi kıyafetlerin ve avatar görünümünün ViewportFrame'de
            -- doğru çizilmesi için korunur; yalnızca çalıştırılabilir scriptler silinir.
            if d:IsA("LuaSourceContainer") then d:Destroy() end
        end

        local previewHumanoid = clone:FindFirstChildOfClass("Humanoid")
        if previewHumanoid then
            previewHumanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
            previewHumanoid.AutoRotate = false
            previewHumanoid.BreakJointsOnDeath = false

            -- Klonun oyuncudan kopyalanan koşma/yürüme animasyonlarını durdur.
            local animator = previewHumanoid:FindFirstChildOfClass("Animator")
            if animator then animator:Destroy() end
            pcall(function() previewHumanoid:ChangeState(Enum.HumanoidStateType.Physics) end)
        end

        -- Önce Viewport'a yerleştirip Motor6D pozlarını nötrle; böylece klon,
        -- oyuncunun o anki koşma/zıplama pozunda takılı kalmaz.
        clone.Parent = MenuCharViewport
        for _, joint in ipairs(clone:GetDescendants()) do
            if joint:IsA("Motor6D") then
                joint.Transform = CFrame.identity
            end
        end
        RunService.Heartbeat:Wait()
        if mySeq ~= buildSeq then clone:Destroy() return end

        local hrp = clone:FindFirstChild("HumanoidRootPart")
        local head = clone:FindFirstChild("Head")
        if not (hrp and head) then clone:Destroy() return end

        -- Önizleme karakterini her seferinde aynı dik, öne bakan yöne çevir.
        local rootPosition = hrp.Position
        local targetRoot = CFrame.new(rootPosition)
        local poseCorrection = targetRoot * hrp.CFrame:Inverse()
        clone:PivotTo(poseCorrection * clone:GetPivot())

        local isR15 = clone:FindFirstChild("UpperTorso") ~= nil
        local function motor(name)
            local m = clone:FindFirstChild(name, true)
            return (m and m:IsA("Motor6D")) and m or nil
        end
        local neck = motor("Neck")
        local shoulder = motor("RightShoulder") or motor("Right Shoulder")

        -- Dönme merkezleri (eklem konumları) eklemler silinmeden önce hesaplanır
        local nPos = head.Position - head.CFrame.UpVector * (head.Size.Y * 0.5)
        if neck and neck.Part0 then nPos = (neck.Part0.CFrame * neck.C0).Position end
        local sPos = nil
        if shoulder and shoulder.Part0 then sPos = (shoulder.Part0.CFrame * shoulder.C0).Position end

        local newHead, newArm = {}, {}
        local function addTo(list, part)
            list[#list + 1] = {part = part, cf = part.CFrame}
        end
        addTo(newHead, head)
        for _, acc in ipairs(clone:GetChildren()) do
            if acc:IsA("Accessory") then
                local handle = acc:FindFirstChild("Handle")
                if handle and handle:IsA("BasePart") then
                    local onHead = false
                    for _, j in ipairs(handle:GetChildren()) do
                        if j:IsA("JointInstance") or j:IsA("WeldConstraint") then
                            if j.Part0 == head or j.Part1 == head then
                                onHead = true
                                j:Destroy()
                            end
                        end
                    end
                    if onHead then addTo(newHead, handle) end
                end
            end
        end
        for _, n in ipairs(isR15 and {"RightUpperArm", "RightLowerArm", "RightHand"} or {"Right Arm"}) do
            local p = clone:FindFirstChild(n)
            if p and p:IsA("BasePart") then addTo(newArm, p) end
        end

        -- Eklemleri kaldır: parçaları kendimiz döndüreceğiz (ViewportFrame'de eklemlere güvenilmez)
        if neck then neck:Destroy() end
        if shoulder then shoulder:Destroy() end
        for _, n in ipairs({"RightElbow", "RightWrist"}) do
            local m = motor(n)
            if m then m:Destroy() end
        end
        for _, d in ipairs(clone:GetDescendants()) do
            if d:IsA("BasePart") then d.Anchored = true end
        end

        -- Kamera: karakterin tamamı (baştan ayağa) görünsün
        local bbCF, bbSize = clone:GetBoundingBox()
        -- Sabit ön görünüş: oyuncu oyunda hangi yöne dönük olursa olsun aynı açı.
        local look = Vector3.new(0, 0, -1)

        local fov = 34
        local abs = MenuCharViewport.AbsoluteSize
        local aspect = (abs.Y > 10) and (abs.X / abs.Y) or 0.64
        local halfV = math.rad(fov / 2)
        local halfH = math.atan(math.tan(halfV) * aspect)
        local distH = (bbSize.Y * 0.5 * 1.08) / math.tan(halfV)
        local distW = (2.4 * 1.05) / math.tan(halfH) -- kol kalkınca genişlik payı
        local dist = math.max(distH, distW) + bbSize.Z * 0.5

        local cam = Instance.new("Camera")
        cam.FieldOfView = fov
        cam.CFrame = CFrame.lookAt(bbCF.Position + look * dist, bbCF.Position)
        cam.Parent = MenuCharViewport
        MenuCharViewport.CurrentCamera = cam

        -- Her şey hazır: eski modeli ancak şimdi kaldır, yenisini devreye al
        local oldModel, oldCam = menuCharModel, menuCam
        menuCharModel = clone
        menuCharBasePivot = clone:GetPivot()
        headGroup, armGroup = newHead, newArm
        neckPos, shoulderPos = nPos, sPos
        menuHrpRot = hrp.CFrame - hrp.CFrame.Position
        menuCam = cam
        if oldModel and oldModel ~= clone then pcall(function() oldModel:Destroy() end) end
        if oldCam and oldCam ~= cam then pcall(function() oldCam:Destroy() end) end
        if onAvatarSwapped then onAvatarSwapped() end
    end)
    if not okBuild then
        warn("[EZRAGOX] Önizleme hatası: " .. tostring(errBuild))
        if clone and clone ~= menuCharModel then pcall(function() clone:Destroy() end) end
        if menuCam and menuCam.Parent == MenuCharViewport then
            MenuCharViewport.CurrentCamera = menuCam
        end
    end
end
refreshMenuAvatar = buildMenuAvatar
task.spawn(function()
    if not LocalPlayer.Character then LocalPlayer.CharacterAdded:Wait() end
    buildMenuAvatar()
end)

-- Performans: karakterin BasePart listesi (0.5 sn'de bir yenilenir; noclip her karede GetDescendants yapmasın)
do
    local cache, cacheAt, cacheChar = {}, 0, nil
    Settings.CharParts = function(ch)
        local now = os.clock()
        if ch ~= cacheChar or now - cacheAt > 0.5 then
            cacheChar, cacheAt = ch, now
            cache = {}
            for _, d in ipairs(ch:GetDescendants()) do
                if d:IsA("BasePart") then cache[#cache + 1] = d end
            end
        end
        return cache
    end
end

-- ORTAK OYUNCU ÖNİZLEME: oyuncu listelerinde fare hangi oyuncunun üzerindeyse onun karakteri
-- menünün sağındaki karakter alanında görünür; üzerinden çekilince / seçim yapılınca / liste
-- kapanınca kendi karakterim geri gelir. Tüm oyuncu seçme listeleri bunu kullanır.
do
    local tok, shown = 0, nil
    local function viewportOk()
        local cam = MenuCharViewport.CurrentCamera
        return MenuCharViewport:FindFirstChildOfClass("Model") ~= nil
            and cam ~= nil and cam.Parent == MenuCharViewport
    end
    Settings.PlayerPreview = function(plr)
        tok = tok + 1
        local my = tok
        task.delay(0.12, function()
            if not alive or my ~= tok or not refreshMenuAvatar then return end
            if plr ~= nil then
                shown = plr
                pcall(refreshMenuAvatar, plr)
                return
            end
            -- Kendi karakterime dön (boş kalırsa 3 kereye kadar tekrar dene)
            if shown == nil and viewportOk() then return end
            shown = nil
            for _ = 1, 3 do
                pcall(refreshMenuAvatar, LocalPlayer)
                if my ~= tok or viewportOk() then break end
                task.wait(0.3)
            end
        end)
    end
    -- Liste kapanınca ya da bulunduğu sayfa gizlenince önizlemeyi kendi karakterime döndür
    Settings.PlayerPreviewBind = function(list)
        local function reset() Settings.PlayerPreview(nil) end
        bind(list:GetPropertyChangedSignal("Visible"), function()
            if not list.Visible then reset() end
        end)
        local pg = list.Parent
        if pg then
            bind(pg:GetPropertyChangedSignal("Visible"), function()
                if not pg.Visible then reset() end
            end)
        end
    end
end

-- Karakter fareyle sürüklenirken yumuşak döner; hızlı bırakmada ataletle
-- bir süre hızlı dönüp kademeli olarak normal dönüş hızına iner.
local AVATAR_TURN_SPEED = math.rad(32)
local AVATAR_DRAG_SENSITIVITY = 0.012
local AVATAR_SMOOTHNESS = 16
local AVATAR_MAX_DRAG_SPEED = math.rad(720)
local AVATAR_INERTIA_DECAY = 2.8

local avatarTurnAngle = 0
local avatarTargetAngle = 0
local avatarDragging = false
local avatarLastMouseX = nil
local avatarLastInputTime = nil
local avatarDragVelocity = 0
local avatarAngularVelocity = AVATAR_TURN_SPEED

-- Karakter değişince yeni karakter öne bakarak baştan dönmeye başlar.
onAvatarSwapped = function()
    avatarTurnAngle = 0
    avatarTargetAngle = 0
    avatarAngularVelocity = AVATAR_TURN_SPEED
end

-- Menü açıkken her 5 saniyede bir kısa el sallama hareketi.
local AVATAR_WAVE_INTERVAL = 5
local AVATAR_WAVE_DURATION = 1.25
local nextAvatarWaveAt = os.clock() + AVATAR_WAVE_INTERVAL
local avatarWaveStartedAt = nil

local function wrapAngleDelta(a)
    return (a + math.pi) % (math.pi * 2) - math.pi
end

bind(MenuCharViewport.InputBegan, function(input)
    if not menuOpen or not MenuCharViewport.Visible then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        avatarDragging = true
        avatarLastMouseX = input.Position.X
        avatarLastInputTime = os.clock()
        avatarDragVelocity = 0
        avatarAngularVelocity = 0
    end
end)

bind(UserInputService.InputChanged, function(input)
    if not avatarDragging or not menuOpen then return end
    if input.UserInputType == Enum.UserInputType.MouseMovement and avatarLastMouseX then
        local now = os.clock()
        local deltaX = input.Position.X - avatarLastMouseX
        local elapsed = math.max(now - (avatarLastInputTime or now), 1 / 240)
        avatarLastMouseX = input.Position.X
        avatarLastInputTime = now

        -- Pozitif fare hareketi karakteri aynı yönde çevirir.
        local angleDelta = deltaX * AVATAR_DRAG_SENSITIVITY
        avatarTargetAngle = avatarTargetAngle + angleDelta
        local measuredVelocity = math.clamp(angleDelta / elapsed, -AVATAR_MAX_DRAG_SPEED, AVATAR_MAX_DRAG_SPEED)
        avatarDragVelocity = avatarDragVelocity * 0.35 + measuredVelocity * 0.65
    end
end)

bind(UserInputService.InputEnded, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 and avatarDragging then
        avatarDragging = false
        avatarLastMouseX = nil
        avatarLastInputTime = nil
        -- Bırakıldığı andaki hız korunur; RenderStepped bunu yumuşakça azaltır.
        avatarAngularVelocity = math.clamp(avatarDragVelocity, -AVATAR_MAX_DRAG_SPEED, AVATAR_MAX_DRAG_SPEED)
    end
end)

bind(RunService.RenderStepped, function(dt)
    if not menuOpen or not menuCharModel or not menuCharModel.Parent or not menuCharBasePivot then return end
    pcall(function()
        if avatarDragging then
            local difference = wrapAngleDelta(avatarTargetAngle - avatarTurnAngle)
            local alpha = 1 - math.exp(-AVATAR_SMOOTHNESS * dt)
            avatarTurnAngle = avatarTurnAngle + difference * alpha
        else
            -- Atalet hızı normal dönüş hızına doğru üstel olarak yaklaşır.
            local decay = math.exp(-AVATAR_INERTIA_DECAY * dt)
            avatarAngularVelocity = AVATAR_TURN_SPEED + (avatarAngularVelocity - AVATAR_TURN_SPEED) * decay
            avatarTurnAngle = avatarTurnAngle + avatarAngularVelocity * dt
            avatarTargetAngle = avatarTurnAngle
        end

        local currentPivot = menuCharBasePivot * CFrame.Angles(0, avatarTurnAngle, 0)
        menuCharModel:PivotTo(currentPivot)

        -- Kol parçaları, karakterin mevcut dönüş açısı korunarak omuzdan hareket ettirilir.
        if #armGroup > 0 and shoulderPos then
            local now = os.clock()
            if not avatarWaveStartedAt and now >= nextAvatarWaveAt then
                avatarWaveStartedAt = now
                nextAvatarWaveAt = now + AVATAR_WAVE_INTERVAL
            end

            local waveAngle = 0
            local waveWiggle = 0
            if avatarWaveStartedAt then
                local elapsed = now - avatarWaveStartedAt
                if elapsed >= AVATAR_WAVE_DURATION then
                    avatarWaveStartedAt = nil
                else
                    local progress = math.clamp(elapsed / AVATAR_WAVE_DURATION, 0, 1)
                    -- Yumuşak giriş/çıkış; kol belirgin biçimde kalkar ve birkaç kez sallar.
                    local envelope = math.sin(progress * math.pi)
                    waveAngle = math.rad(125) * envelope
                    waveWiggle = math.rad(30) * math.sin(elapsed * 17) * envelope
                end
            end

            local modelDelta = currentPivot * menuCharBasePivot:Inverse()
            local shoulderWorld = modelDelta:PointToWorldSpace(shoulderPos)
            local characterRotation = modelDelta.Rotation * menuHrpRot
            -- Omuz ekseni karakterin yerel Z eksenidir; bilek/kol grubu beraber hareket eder.
            local armRotation = characterRotation
                * CFrame.Angles(0, 0, waveAngle + waveWiggle)
                * characterRotation:Inverse()
            local shoulderTransform = CFrame.new(shoulderWorld) * armRotation * CFrame.new(-shoulderWorld)

            for _, entry in ipairs(armGroup) do
                if entry.part and entry.part.Parent then
                    entry.part.CFrame = shoulderTransform * modelDelta * entry.cf
                end
            end
        end
    end)
end)
end

---------------------------------------------------------
-- 7. MİNİ LOGO
---------------------------------------------------------
-- Küçültülmüş arayüz düğmesinde yalnızca ana logo görseli kullanılır.
local MiniLogo = new("ImageButton", {
    AnchorPoint = Vector2.new(0.5, 0),
    Size = UDim2.new(0, 190, 0, 46),
    Position = UDim2.new(0.5, 0, 0, 24),
    BackgroundTransparency = 1,
    AutoButtonColor = false,
    Image = "rbxassetid://84152160938421",
    ScaleType = Enum.ScaleType.Fit,
    ImageTransparency = 0,
    Visible = false,
    ZIndex = 10,
}, ScreenGui)
local MiniScale = new("UIScale", {Scale = 1}, MiniLogo)
ctaFx(MiniLogo, {scale = MiniScale, colors = false, overlay = false})
task.spawn(function()
    local cp = game:GetService("ContentProvider")
    pcall(function() cp:PreloadAsync({MiniLogo}) end)
    if not MiniLogo.IsLoaded then
        MiniLogo.Image = "rbxthumb://type=Asset&id=84152160938421&w=420&h=420"
        pcall(function() cp:PreloadAsync({MiniLogo}) end)
    end
end)
local miniMoved = makeDraggable(MiniLogo, MiniLogo)

---------------------------------------------------------
-- 8. MENÜ AÇ / KAPAT & TEMİZLİK YÖNETİMİ
---------------------------------------------------------
local function menuScale()
    -- Ekranın dört kenarında güvenli boşluk bırak; glow dahil panel sığsın.
    return getScale(W + 72, H + 72, 0.42) * Settings.Scale
end

-- ◢ Boyutlandırma tutamacı: sağ alt köşedeki 3 noktalı üçgen. Basılı tutup sürükle -> menü genişliği ve yüksekliği değişir.
;(function()
    local MIN_W, MIN_H = 600, 440
    local handle = new("TextButton", {
        AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -4, 1, -4), Size = UDim2.new(0, 36, 0, 36),
        BackgroundTransparency = 1, Text = "", AutoButtonColor = false, Active = true, ZIndex = 60,
    }, MainFrame)
    local dots, scales = {}, {}
    for i, pos in ipairs({{26, 14}, {14, 26}, {26, 26}}) do
        local d = new("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, pos[1], 0, pos[2]), Size = UDim2.new(0, 6, 0, 6),
            BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 61,
        }, handle)
        pill(d)
        regFlow(UIFlows, new("UIGradient", {}, d), (i - 1) * 0.18, 0.7)          -- menünün akan renk efekti
        local st = stroke(d, 2, Color3.fromRGB(255, 40, 60), 0.5)
        Pulsers[#Pulsers + 1] = {obj = st, prop = "Transparency", base = 0.5, amp = 0.3, speed = 3 + i * 0.4}
        Pulsers[#Pulsers + 1] = {obj = d, prop = "BackgroundTransparency", base = 0.12, amp = 0.12, speed = 3 + i * 0.4}
        dots[#dots + 1] = d
        scales[#scales + 1] = new("UIScale", {Scale = 1}, d)
    end
    local dragging, hovering = false, false
    local function setHot(on)
        for _, sc in ipairs(scales) do tween(sc, 0.15, {Scale = on and 1.45 or 1}) end
    end
    bind(handle.MouseEnter, function() hovering = true setHot(true) end)
    bind(handle.MouseLeave, function() hovering = false if not dragging then setHot(false) end end)

    local sIn, sW, sH, sPos
    bind(handle.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            sIn, sW, sH, sPos = input.Position, W, H, Window.Position
            setHot(true)
        end
    end)
    bind(UserInputService.InputChanged, function(input)
        if not dragging then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
        local d = input.Position - sIn
        local sc = math.max(MainScale.Scale, 0.1)
        local cam = workspace.CurrentCamera
        local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)
        local nW = math.clamp(sW + d.X / sc, MIN_W, math.max(MIN_W, (vp.X - 30) / sc))
        local nH = math.clamp(sH + d.Y / sc, MIN_H, math.max(MIN_H, (vp.Y - 30) / sc))
        W, H = math.floor(nW), math.floor(nH)
        MainFrame.Size = UDim2.new(0, W, 0, H)
        -- Pencere ortadan büyüdüğü için kaydırarak sol-üst köşeyi sabit tut; sağ-alt köşe imleci takip eder
        Window.Position = UDim2.new(sPos.X.Scale, sPos.X.Offset + (W - sW) * sc / 2, sPos.Y.Scale, sPos.Y.Offset + (H - sH) * sc / 2)
    end)
    bind(UserInputService.InputEnded, function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
            dragging = false
            if not hovering then setHot(false) end
            Settings.WinW, Settings.WinH = W, H
            saveConfig()
        end
    end)
end)()

---------------------------------------------------------
-- MENÜ AÇILIŞ / KAPANIŞ ANİMASYONU  ("Neon Çizgi Patlaması")
-- AÇILIŞ : panel karanlık iki kapakla kapalıdır; ortada parlak bir neon çizgi çakıp iki yana
--          uzar, uçlarından kıvılcımlar saçılır; kapaklar ortadan yukarı/aşağı fırlayıp açılır
--          (ekran hafifçe sarsılır, kenarlık flaş yapar, dışa bir halka yayılır); ardından
--          paneli cam gibi bir ışık süpürür ve karakter sağdan süzülür.
-- KAPANIŞ: kapaklar ortada birleşir, neon çizgi büzülüp tek bir noktaya dönüşür ve patlayarak
--          söner (eski tüplü TV kapanışı gibi).
-- Hızlı aç/kapa yapılsa bile (jeton sistemi) animasyonlar birbirine karışmaz.
---------------------------------------------------------
local MenuFX = {}
do
    local token = 0
    local COVER = Color3.fromRGB(6, 4, 8)
    local HOT = Color3.fromRGB(255, 60, 80)
    local HALF_FULL = UDim2.new(1, 0, 0.5, 22)  -- 22 px taşma: kapaklar ortada birbirinin köşesini örter
    local HALF_NONE = UDim2.new(1, 0, 0, 0)

    local function half(top)
        local f = new("Frame", {
            AnchorPoint = Vector2.new(0.5, top and 0 or 1),
            Position = UDim2.new(0.5, 0, top and 0 or 1, 0),
            Size = HALF_FULL,
            BackgroundColor3 = COVER, BorderSizePixel = 0, ZIndex = 900, Visible = false,
        }, MainFrame)
        corner(f, 22)
        return f
    end
    local TopHalf, BotHalf = half(true), half(false)

    -- Neon çizgi (beyaz çekirdek + kırmızı ışıma) ve yumuşak dikey ışık bulutu
    local Line = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.new(0, 0, 0, 3), BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0, ZIndex = 902, Visible = false,
    }, MainFrame)
    local LineStroke = stroke(Line, 3, HOT, 0.25)
    local LineGlow = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.new(0, 0, 0, 70), BackgroundColor3 = HOT,
        BorderSizePixel = 0, ZIndex = 901, Visible = false,
    }, MainFrame)
    new("UIGradient", {
        Rotation = 90,
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.5, 0.55),
            NumberSequenceKeypoint.new(1, 1),
        }),
    }, LineGlow)

    -- Kapanışta çizginin dönüştüğü nokta
    local Dot = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.new(0, 10, 0, 10), BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0, ZIndex = 903, Visible = false,
    }, MainFrame)
    pill(Dot)
    local DotStroke = stroke(Dot, 4, HOT, 0.3)

    -- Açılıştan sonra paneli süpüren cam parlaması
    local Sheen = new("Frame", {
        Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0, ZIndex = 850, Visible = false,
    }, MainFrame)
    corner(Sheen, 22)
    local SheenGrad = new("UIGradient", {
        Rotation = 25,
        Offset = Vector2.new(-1, 0),
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.4, 1),
            NumberSequenceKeypoint.new(0.5, 0.8),
            NumberSequenceKeypoint.new(0.6, 1),
            NumberSequenceKeypoint.new(1, 1),
        }),
    }, Sheen)

    local charBase = MenuCharViewport.Position

    local function settle()
        TopHalf.Visible = false
        BotHalf.Visible = false
        Line.Visible = false
        LineGlow.Visible = false
        Dot.Visible = false
        Sheen.Visible = false
        MainFrame.Position = UDim2.new(0, 0, 0, 0)
        MenuCharViewport.Position = charBase
        MenuCharViewport.ImageTransparency = 0
    end

    -- Panelin dışına yayılan neon halka
    local function halo()
        local ring = new("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0),
            Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, ZIndex = 0,
        }, MainFrame)
        corner(ring, 24)
        local st = stroke(ring, 3, accentAt(0.5), 0.15)
        tween(ring, 0.65, {Size = UDim2.new(1, 130, 1, 130)}, Enum.EasingStyle.Quint)
        tween(st, 0.65, {Transparency = 1}, Enum.EasingStyle.Quad)
        task.delay(0.7, function() ring:Destroy() end)
    end

    -- Çizginin iki ucundan saçılan kıvılcımlar
    local function sparks()
        for i = 1, 18 do
            local left = (i % 2 == 0)
            local sz = math.random(2, 5)
            local f = new("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(left and 0 or 1, 0, 0.5, 0),
                Size = UDim2.new(0, sz, 0, sz),
                BackgroundColor3 = (i % 3 == 0) and Color3.new(1, 1, 1) or HOT,
                BorderSizePixel = 0, ZIndex = 905,
            }, MainFrame)
            pill(f)
            local dx = math.random(30, 160) * (left and -1 or 1)
            local dy = math.random(-70, 70)
            local dur = 0.35 + math.random() * 0.35
            tween(f, dur, {
                Position = UDim2.new(left and 0 or 1, dx, 0.5, dy),
                BackgroundTransparency = 1,
            }, Enum.EasingStyle.Quad)
            task.delay(dur + 0.05, function() f:Destroy() end)
        end
    end

    -- Kısa, sönümlenen ekran sarsıntısı
    local function shake(power, dur, my)
        task.spawn(function()
            local t0 = os.clock()
            while os.clock() - t0 < dur and token == my do
                local k = 1 - (os.clock() - t0) / dur
                MainFrame.Position = UDim2.new(0, (math.random() * 2 - 1) * power * k, 0, (math.random() * 2 - 1) * power * k)
                RunService.RenderStepped:Wait()
            end
            if token == my then MainFrame.Position = UDim2.new(0, 0, 0, 0) end
        end)
    end

    function MenuFX.open(first)
        token = token + 1
        local my = token
        local s = menuScale()
        local k = first and 1.3 or 1 -- giriş animasyonundan sonraki ilk açılış biraz daha uzun

        -- Başlangıç: kapaklar kapalı, çizgi sıfır genişlikte
        settle()
        TopHalf.Size = HALF_FULL
        BotHalf.Size = HALF_FULL
        TopHalf.Visible = true
        BotHalf.Visible = true
        Line.Size = UDim2.new(0, 0, 0, 3)
        Line.BackgroundTransparency = 0
        LineStroke.Transparency = 0.25
        Line.Visible = true
        LineGlow.Size = UDim2.new(0, 0, 0, 70)
        LineGlow.BackgroundTransparency = 0
        LineGlow.Visible = true
        MenuCharViewport.Position = charBase + UDim2.new(0, 46, 0, 0)
        MenuCharViewport.ImageTransparency = 1
        MainScale.Scale = s * (first and 0.7 or 0.9)
        MainStroke.Thickness = 2

        -- A) Çizgi çakar ve iki yana uzar
        playSound(2.4, 0.22)
        tween(Line, 0.2 * k, {Size = UDim2.new(1, 0, 0, 3)}, Enum.EasingStyle.Quint)
        tween(LineGlow, 0.2 * k, {Size = UDim2.new(1, 0, 0, 70)}, Enum.EasingStyle.Quint)
        tween(MainScale, 0.75 * k, {Scale = s}, Enum.EasingStyle.Back)

        -- B) Kapaklar ortadan fırlayıp açılır
        task.delay(0.2 * k, function()
            if token ~= my then return end
            playSound(0.7, 0.35)
            tween(TopHalf, 0.5 * k, {Size = HALF_NONE}, Enum.EasingStyle.Quart)
            tween(BotHalf, 0.5 * k, {Size = HALF_NONE}, Enum.EasingStyle.Quart)
            tween(Line, 0.45 * k, {Size = UDim2.new(1, 0, 0, 7), BackgroundTransparency = 1}, Enum.EasingStyle.Quad)
            tween(LineStroke, 0.45 * k, {Transparency = 1}, Enum.EasingStyle.Quad)
            tween(LineGlow, 0.5 * k, {Size = UDim2.new(1, 0, 0, 170), BackgroundTransparency = 1}, Enum.EasingStyle.Quad)
            MainStroke.Thickness = 7
            tween(MainStroke, 0.8, {Thickness = 2}, Enum.EasingStyle.Quint)
            GlowStroke.Transparency = 0.25
            tween(GlowStroke, 0.9, {Transparency = 0.91}, Enum.EasingStyle.Quad)
            halo()
            sparks()
            shake(5, 0.28, my)
        end)
        task.delay(0.75 * k, function()
            if token ~= my then return end
            TopHalf.Visible = false
            BotHalf.Visible = false
            Line.Visible = false
            LineGlow.Visible = false
        end)

        -- C) Cam parlaması panelden geçer, karakter sağdan süzülür
        task.delay(0.55 * k, function()
            if token ~= my then return end
            SheenGrad.Offset = Vector2.new(-1, 0)
            Sheen.Visible = true
            tween(SheenGrad, 0.8, {Offset = Vector2.new(1, 0)}, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
            tween(MenuCharViewport, 0.6, {Position = charBase}, Enum.EasingStyle.Quint)
            tween(MenuCharViewport, 0.5, {ImageTransparency = 0}, Enum.EasingStyle.Sine)
        end)
        task.delay(0.55 * k + 0.9, function()
            if token == my then Sheen.Visible = false end
        end)
        task.delay(0.55 * k + 0.2, function()
            if token == my then playSound(1.9, 0.2) end
        end)
    end

    -- final = true: panel tamamen yok olacak şekilde çöker (arayüz kapatılırken)
    function MenuFX.close(done, final)
        token = token + 1
        local my = token
        local s = menuScale()

        Sheen.Visible = false
        Dot.Visible = false
        Line.Visible = false
        LineGlow.Visible = false
        MainFrame.Position = UDim2.new(0, 0, 0, 0)
        TopHalf.Size = HALF_NONE
        BotHalf.Size = HALF_NONE
        TopHalf.Visible = true
        BotHalf.Visible = true

        -- Karakter silinir, panel hafifçe çöker
        tween(MenuCharViewport, 0.22, {Position = charBase + UDim2.new(0, 38, 0, 0), ImageTransparency = 1}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        tween(MainScale, final and 0.55 or 0.36, {Scale = final and (s * 0.05) or (s * 0.94)}, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
        playSound(1.1, 0.25)

        -- Kapaklar ortada birleşir
        tween(TopHalf, 0.24, {Size = HALF_FULL}, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
        tween(BotHalf, 0.24, {Size = HALF_FULL}, Enum.EasingStyle.Quart, Enum.EasingDirection.In)

        -- Neon çizgi belirir ve tek noktaya büzülür
        task.delay(0.22, function()
            if token ~= my then return end
            Line.Size = UDim2.new(1, 0, 0, 3)
            Line.BackgroundTransparency = 0
            LineStroke.Transparency = 0.25
            Line.Visible = true
            LineGlow.Size = UDim2.new(1, 0, 0, 70)
            LineGlow.BackgroundTransparency = 0
            LineGlow.Visible = true
            tween(Line, 0.14, {Size = UDim2.new(0, 6, 0, 3)}, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
            tween(LineGlow, 0.14, {Size = UDim2.new(0, 24, 0, 70), BackgroundTransparency = 1}, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
        end)
        -- Nokta patlayarak söner
        task.delay(0.34, function()
            if token ~= my then return end
            Line.Visible = false
            LineGlow.Visible = false
            Dot.Size = UDim2.new(0, 10, 0, 10)
            Dot.BackgroundTransparency = 0
            DotStroke.Transparency = 0.3
            Dot.Visible = true
            tween(Dot, 0.22, {Size = UDim2.new(0, 48, 0, 48), BackgroundTransparency = 1}, Enum.EasingStyle.Quad)
            tween(DotStroke, 0.22, {Transparency = 1}, Enum.EasingStyle.Quad)
            playSound(2.6, 0.2)
        end)

        task.delay(0.56, function()
            if token ~= my then return end
            settle()
            MainStroke.Thickness = 2
            if done then done() end
        end)
    end
end

-- Menü ilk kez açıldığında bir kez çalacak karşılama sesi.
-- Menü kapatılıp tekrar açıldığında yeniden tetiklenmez.
local menuIntroSoundPlayed = false
local function playMenuIntroSoundOnce()
    if menuIntroSoundPlayed then return end
    menuIntroSoundPlayed = true

    task.spawn(function()
        local sound
        local ok = pcall(function()
            sound = Instance.new("Sound")
            sound.Name = "EZRAGOX_MenuWelcomeSound"
            sound.SoundId = "rbxassetid://118900643276596"
            sound.Volume = 0.85
            sound.Looped = false
            sound.Parent = SoundService

            game:GetService("ContentProvider"):PreloadAsync({sound})

            local startedAt = os.clock()
            while sound.Parent and not sound.IsLoaded and os.clock() - startedAt < 10 do
                task.wait(0.1)
            end

            if sound.Parent and sound.IsLoaded then
                sound:Play()
                sound.Ended:Connect(function()
                    if sound then sound:Destroy() end
                end)
            else
                warn("[EZRAGOX HUB] Menü karşılama sesi yüklenemedi: 118900643276596")
                sound:Destroy()
            end
        end)

        if not ok then
            if sound then pcall(function() sound:Destroy() end) end
            warn("[EZRAGOX HUB] Menü karşılama sesi başlatılamadı.")
        end
    end)
end

local function setMenu(open)
    if open == menuOpen or not ready then return end
    menuOpen = open
    playClickSound()
    fxResetAll(false)
    if open then
        MiniLogo.Visible = false
        MainFrame.Visible = true
        MenuCharViewport.Visible = true
        if refreshMenuAvatar then
            task.spawn(function()
                if alive and menuOpen then
                    refreshMenuAvatar()
                end
            end)
        end
        MenuFX.open(false)
        if Settings.Blur then
            blurEffect.Enabled = true
            tween(blurEffect, 0.3, {Size = 12})
        end
    else
        tween(blurEffect, 0.25, {Size = 0})
        MenuFX.close(function()
            if alive and not menuOpen then
                MainFrame.Visible = false
                MenuCharViewport.Visible = false
                blurEffect.Enabled = false
                MiniLogo.Visible = true
                MiniScale.Scale = 0.6
                tween(MiniScale, 0.3, {Scale = 1}, Enum.EasingStyle.Back)
            end
        end)
    end
end

local function closeAll()
    saveConfig()
    if not alive then return end
    alive = false
    for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    if shieldCleanup then pcall(shieldCleanup) end
    -- Seçili gökyüzü, panel kapatılıp script yeniden çalıştırıldığında da korunur.
    if antiFlingCleanup then pcall(antiFlingCleanup) end
    -- ESP işaretlerini (yeşil çerçeve + isimler) temizle
    pcall(function()
        local host = ScreenGui.Parent
        local f = host and host:FindFirstChild("EZRAGOX_ESP")
        if f then f:Destroy() end
    end)
    -- Başka bir oyuncuyu izliyorsak kamerayı kendi karakterimize geri ver
    pcall(function()
        local cam = workspace.CurrentCamera
        local myChar = LocalPlayer.Character
        local myHum = myChar and myChar:FindFirstChildOfClass("Humanoid")
        if cam and myHum and cam.CameraSubject ~= myHum then
            cam.CameraSubject = myHum
        end
    end)
    local animate = MainFrame.Visible and ready
    if animate then
        pcall(function() MenuFX.close(nil, true) end)
    else
        tween(MainScale, 0.2, {Scale = 0.05}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
    end
    tween(blurEffect, 0.2, {Size = 0})
    task.delay(animate and 0.75 or 0.3, function()
        pcall(function() blurEffect:Destroy() end)
        pcall(function() cc:Destroy() end)
        pcall(function() ScreenGui:Destroy() end)
    end)
end

if getgenv then
    getgenv().EZRAGOX_HUB_CLEANUP = closeAll
end

bind(MinimizeBtn.MouseButton1Click, function() setMenu(false) end)
do
    -- closeAll tüm bağlantıları anında kopardığı için çarpı tuşunun tıklama efektleri
    -- (onay sesleri, yeşil flaş) yarım kalıyordu. Efektler görünsün diye kapanış kısa süre beklenir.
    local closing = false
    bind(CloseBtn.MouseButton1Click, function()
        if closing then return end
        closing = true
        task.delay(0.3, closeAll)
    end)
end
bind(MiniLogo.Activated, function()
    if miniMoved() then return end
    setMenu(true)
end)

bind(UserInputService.InputBegan, function(input, gpe)
    if gpe or not ready then return end
    if listeningForKey then
        if input.UserInputType == Enum.UserInputType.Keyboard then
            Settings.ToggleKey = input.KeyCode
            listeningForKey = false
            if updateKeyTextCallback then
                updateKeyTextCallback(Settings.ToggleKey.Name)
            end
            setText(SidebarKeyHint, Settings.ToggleKey.Name .. "  •  menüyü aç / kapat")
            saveConfig()
            notify("Menü Tuşu Değiştirildi", "Yeni kısayol: " .. Settings.ToggleKey.Name, 3)
        end
        return
    end

    if listeningFlyKey then
        if input.UserInputType == Enum.UserInputType.Keyboard then
            Settings.FlyKey = input.KeyCode
            listeningFlyKey = false
            if updateFlyKeyTextCallback then
                updateFlyKeyTextCallback(Settings.FlyKey.Name)
            end
            saveConfig()
            notify("Fly Tuşu Değiştirildi", "Yeni Fly tuşu: " .. Settings.FlyKey.Name, 3)
        end
        return
    end

    if input.KeyCode == Settings.ToggleKey then
        setMenu(not menuOpen)
    end
end)

---------------------------------------------------------
-- 9. SAYFALAR
---------------------------------------------------------
local HomePage = createTab("Ana Sayfa", "⌂")
do local l = HomePage:FindFirstChildOfClass("UIListLayout") if l then l.Padding = UDim.new(0, 8) end end
local FeaturesPage = createTab("Özellikler", "")
---------------------------------------------------------
-- ORTAK FLING MODÜLÜ  (MM2 sekmesi + Özellikler sekmesi aynı sistemi kullanır)
-- Üç yol: 🎯 isim yaz + butona bas  •  👆 çift tıkla  •  🤝 dokun (walk fling)
-- Kendi fonksiyonunun içinde çalışır: ana bölümdeki local sayısını artırmaz.
---------------------------------------------------------
;(function()
    local function isAlive(plr)
        local c = plr.Character
        local h = c and c:FindFirstChildOfClass("Humanoid")
        return h ~= nil and h.Health > 0 and c:FindFirstChild("HumanoidRootPart") ~= nil
    end

    ---------------------------------------------------------
    -- FIRLATMA (1000x GÜÇ)  •  seçili oyuncuyu fizik çarpışmasıyla fırlatır
    -- Not: Diğer oyuncunun karakterinde doğrudan yapılan değişiklikler sunucuya
    -- yansımaz; gerçek etki kendi karakterini hedefin içine ışınlayıp anormal
    -- derecede yüksek hızla çarptırmaktan gelir (Troll sekmesindeki fling ile
    -- aynı yöntem, istek üzerine gücü 1000 kat artırılmış hali).
    ---------------------------------------------------------
    local mm2FlingBusy = false
    local flingOldPos = nil -- YARHM'deki getgenv().OldPos ile birebir aynı rol: kendi karakterinin fling öncesi konumu
    -- YARHM'in "SkidFling" fonksiyonunun BİREBİR portu: aynı sabitler (9e7, 9e7*10, 9e8...),
    -- aynı CFrame + Velocity/RotVelocity ikili ataması, aynı "hızlıyken/duruyorken" iki desen,
    -- aynı Seated state açıp kapatma, aynı "GettingUp" ile geri dönüş döngüsü.
    -- Tek fark: YARHM'deki "Oyuncu zaten flung, tekrar fırlatılsın mı?" onay penceresi burada
    -- yok (bu scriptte YARHM'deki gibi bir dialog sistemi yok), o yüzden doğrudan devam eder.
    local function flingTarget(plr)
        if mm2FlingBusy then
            notify("Bekle", "Önceki fırlatma hâlâ sürüyor.", 2)
            return
        end
        if not plr or not plr.Parent then
            notify("Hata", "Lütfen önce bir hedef oyuncu seçin!", 3)
            return
        end

        mm2FlingBusy = true
        task.spawn(function()
            local Character = LocalPlayer.Character
            local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
            local RootPart = Humanoid and Humanoid.RootPart
            local oldFallenHeight = workspace.FallenPartsDestroyHeight -- YARHM'deki getgenv().FPDH karşılığı: eski değeri burada kendimiz saklıyoruz

            local TargetPlayer = plr
            local TCharacter = TargetPlayer.Character

            if Character and Humanoid and RootPart and TCharacter then
                local THumanoid, TRootPart, THead, Accessory, Handle

                if TCharacter:FindFirstChildOfClass("Humanoid") then
                    THumanoid = TCharacter:FindFirstChildOfClass("Humanoid")
                end
                if THumanoid and THumanoid.RootPart then
                    TRootPart = THumanoid.RootPart
                end
                if TCharacter:FindFirstChild("Head") then
                    THead = TCharacter.Head
                end
                if TCharacter:FindFirstChildOfClass("Accessory") then
                    Accessory = TCharacter:FindFirstChildOfClass("Accessory")
                end
                if Accessory and Accessory:FindFirstChild("Handle") then
                    Handle = Accessory.Handle
                end

                if RootPart.Velocity.Magnitude < 50 then
                    flingOldPos = RootPart.CFrame
                end

                if THead then
                    workspace.CurrentCamera.CameraSubject = THead
                elseif not THead and Handle then
                    workspace.CurrentCamera.CameraSubject = Handle
                elseif THumanoid and TRootPart then
                    workspace.CurrentCamera.CameraSubject = THumanoid
                end

                if not TCharacter:FindFirstChildWhichIsA("BasePart") then
                    mm2FlingBusy = false
                    return
                end

                local FPos = function(BasePart, Pos, Ang)
                    RootPart.CFrame = CFrame.new(BasePart.Position) * Pos * Ang
                    Character:SetPrimaryPartCFrame(CFrame.new(BasePart.Position) * Pos * Ang)
                    RootPart.Velocity = Vector3.new(9e7, 9e7 * 10, 9e7)
                    RootPart.RotVelocity = Vector3.new(9e8, 9e8, 9e8)
                end

                local SFBasePart = function(BasePart)
                    local TimeToWait = 2
                    local Time = tick()
                    local Angle = 0

                    repeat
                        if RootPart and THumanoid then
                            if BasePart.Velocity.Magnitude < 50 then
                                Angle = Angle + 100

                                FPos(BasePart, CFrame.new(0, 1.5, 0) + THumanoid.MoveDirection * BasePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle), 0, 0))
                                task.wait()

                                FPos(BasePart, CFrame.new(0, -1.5, 0) + THumanoid.MoveDirection * BasePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle), 0, 0))
                                task.wait()

                                FPos(BasePart, CFrame.new(2.25, 1.5, -2.25) + THumanoid.MoveDirection * BasePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle), 0, 0))
                                task.wait()

                                FPos(BasePart, CFrame.new(-2.25, -1.5, 2.25) + THumanoid.MoveDirection * BasePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle), 0, 0))
                                task.wait()

                                FPos(BasePart, CFrame.new(0, 1.5, 0) + THumanoid.MoveDirection, CFrame.Angles(math.rad(Angle), 0, 0))
                                task.wait()

                                FPos(BasePart, CFrame.new(0, -1.5, 0) + THumanoid.MoveDirection, CFrame.Angles(math.rad(Angle), 0, 0))
                                task.wait()
                            else
                                FPos(BasePart, CFrame.new(0, 1.5, THumanoid.WalkSpeed), CFrame.Angles(math.rad(90), 0, 0))
                                task.wait()

                                FPos(BasePart, CFrame.new(0, -1.5, -THumanoid.WalkSpeed), CFrame.Angles(0, 0, 0))
                                task.wait()

                                FPos(BasePart, CFrame.new(0, 1.5, THumanoid.WalkSpeed), CFrame.Angles(math.rad(90), 0, 0))
                                task.wait()

                                FPos(BasePart, CFrame.new(0, 1.5, TRootPart.Velocity.Magnitude / 1.25), CFrame.Angles(math.rad(90), 0, 0))
                                task.wait()

                                FPos(BasePart, CFrame.new(0, -1.5, -TRootPart.Velocity.Magnitude / 1.25), CFrame.Angles(0, 0, 0))
                                task.wait()

                                FPos(BasePart, CFrame.new(0, 1.5, TRootPart.Velocity.Magnitude / 1.25), CFrame.Angles(math.rad(90), 0, 0))
                                task.wait()

                                FPos(BasePart, CFrame.new(0, -1.5, 0), CFrame.Angles(math.rad(90), 0, 0))
                                task.wait()

                                FPos(BasePart, CFrame.new(0, -1.5, 0), CFrame.Angles(0, 0, 0))
                                task.wait()

                                FPos(BasePart, CFrame.new(0, -1.5, 0), CFrame.Angles(math.rad(-90), 0, 0))
                                task.wait()

                                FPos(BasePart, CFrame.new(0, -1.5, 0), CFrame.Angles(0, 0, 0))
                                task.wait()
                            end
                        else
                            break
                        end
                    until BasePart.Velocity.Magnitude > 500
                        or BasePart.Parent ~= TargetPlayer.Character
                        or TargetPlayer.Parent ~= Players
                        or TargetPlayer.Character ~= TCharacter
                        or (THumanoid and THumanoid.Sit)
                        or Humanoid.Health <= 0
                        or tick() > Time + TimeToWait
                end

                workspace.FallenPartsDestroyHeight = 0 / 0

                local BV = Instance.new("BodyVelocity")
                BV.Name = "EZRAGOX_FlingVel"
                BV.Parent = RootPart
                BV.Velocity = Vector3.new(9e8, 9e8, 9e8)
                BV.MaxForce = Vector3.new(1 / 0, 1 / 0, 1 / 0)

                Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, false)

                if TRootPart and THead then
                    if (TRootPart.CFrame.p - THead.CFrame.p).Magnitude > 5 then
                        SFBasePart(THead)
                    else
                        SFBasePart(TRootPart)
                    end
                elseif TRootPart and not THead then
                    SFBasePart(TRootPart)
                elseif not TRootPart and THead then
                    SFBasePart(THead)
                elseif not TRootPart and not THead and Accessory and Handle then
                    SFBasePart(Handle)
                else
                    notify("Hata", "Hedef oyuncunun fırlatılacak uygun bir parçası bulunamadı.", 3)
                end

                BV:Destroy()
                Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, true)
                workspace.CurrentCamera.CameraSubject = Humanoid

                repeat
                    RootPart.CFrame = flingOldPos * CFrame.new(0, .5, 0)
                    Character:SetPrimaryPartCFrame(flingOldPos * CFrame.new(0, .5, 0))
                    Humanoid:ChangeState("GettingUp")
                    table.foreach(Character:GetChildren(), function(_, x)
                        if x:IsA("BasePart") then
                            x.Velocity, x.RotVelocity = Vector3.new(), Vector3.new()
                        end
                    end)
                    task.wait()
                until (RootPart.Position - flingOldPos.p).Magnitude < 25
                workspace.FallenPartsDestroyHeight = oldFallenHeight

                mm2FlingBusy = false
                notify("Fırlatma", TargetPlayer.Name .. " fırlatıldı (veya denendi).", 3)
            else
                mm2FlingBusy = false
                notify("Hata", "Hedef oyuncunun geçerli bir karakteri yok. Ölmüş olabilir.", 3)
            end
        end)
    end


    local clickOn, touchOn = false, false
    local touchConns = {}
    local lastClickPl, lastClickT = nil, 0
    local mouse = LocalPlayer:GetMouse()
    local painters = {}

        local function plrFromPart(part)
            local m = part and part:FindFirstAncestorOfClass("Model")
            local pl = m and Players:GetPlayerFromCharacter(m)
            if pl and pl ~= LocalPlayer and isAlive(pl) then return pl end
            return nil
        end

        local function clearTouch()
            for _, c in ipairs(touchConns) do pcall(function() c:Disconnect() end) end
            touchConns = {}
        end
        -- DOKUNARAK = "walk fling": karakterin yerinde kalır, normal yürürsün (ışınlanma / dönme YOK).
        -- Biri sana dokununca (ya da sen ona) kısa bir an fizik hızı verilir; hız bir sonraki
        -- karede geri alındığı için ekranında hiçbir şey görünmez, dokunan oyuncu fırlar.
        local flingUntil, wfRunning, lastTouchNotify = 0, false, 0
        local function startWalkFling()
            if wfRunning then return end
            wfRunning = true
            task.spawn(function()
                while alive and touchOn do
                    RunService.Heartbeat:Wait()
                    if os.clock() < flingUntil and not mm2FlingBusy then
                        local ch = LocalPlayer.Character
                        local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
                        if hrp then
                            local vel = hrp.AssemblyLinearVelocity
                            hrp.AssemblyLinearVelocity = vel * 10000 + Vector3.new(0, 10000, 0)
                            RunService.RenderStepped:Wait()
                            if hrp.Parent then hrp.AssemblyLinearVelocity = vel end
                            RunService.Stepped:Wait()
                            if hrp.Parent then
                                hrp.AssemblyLinearVelocity = vel + Vector3.new(0, (os.clock() % 0.2 < 0.1) and 0.1 or -0.1, 0)
                            end
                        end
                    end
                end
                wfRunning = false
            end)
        end
        local function onTouched(other)
            if not touchOn then return end
            local pl = plrFromPart(other)
            if not pl then return end
            flingUntil = os.clock() + 1.5
            local now = os.clock()
            if now - lastTouchNotify > 1.5 then
                lastTouchNotify = now
                notify("🤝  Dokunma Fırlatması", pl.Name .. " sana dokundu, fırlatılıyor!", 2)
            end
        end
        local function hookChar(ch)
            clearTouch()
            if not (touchOn and ch) then return end
            for _, p in ipairs(ch:GetChildren()) do
                if p:IsA("BasePart") then
                    touchConns[#touchConns + 1] = p.Touched:Connect(onTouched)
                end
            end
        end
        bind(LocalPlayer.CharacterAdded, function(ch)
            task.wait(0.6)
            hookChar(ch)
        end)

        -- Tıklayarak: fareyle / dokunmatik ekranla tıkladığın oyuncuyu fırlat
        bind(UserInputService.InputBegan, function(input, gpe)
            if not clickOn or gpe or mm2FlingBusy or GuiService.MenuIsOpen then return end
            local t = input.UserInputType
            if t ~= Enum.UserInputType.MouseButton1 and t ~= Enum.UserInputType.Touch then return end
            -- Oyun içi normal tıklamalar (ateş / bıçak) yanlışlıkla fırlatma yapmasın:
            -- aynı oyuncuya 0.4 sn içinde ÇİFT tıklamak gerekir.
            local pl = plrFromPart(mouse.Target)
            local now = os.clock()
            if pl and pl == lastClickPl and now - lastClickT < 0.4 then
                lastClickPl = nil
                flingTarget(pl)
            else
                lastClickPl, lastClickT = pl, now
            end
        end)


    local function addModes(page)
        local row = baseRow(page, "Frame", 42)
        local function modeBtn(text, xScale, xOff, kind)
            local b = new("TextButton", {
                Size = UDim2.new(0.5, -14, 0, 30), Position = UDim2.new(xScale, xOff, 0.5, -15),
                AutoButtonColor = false, Text = text, Font = Enum.Font.GothamBold, TextSize = 13,
                BackgroundColor3 = Color3.fromRGB(28, 34, 54), TextColor3 = Color3.fromRGB(150, 162, 190), ZIndex = 4,
            }, row)
            corner(b, 8)
            local st = stroke(b, 1, Color3.fromRGB(55, 65, 95), 0.3)
            local function paint()
                local on = (kind == "click") and clickOn or touchOn
                tween(b, 0.18, {
                    BackgroundColor3 = on and Color3.fromRGB(190, 32, 48) or Color3.fromRGB(28, 34, 54),
                    TextColor3 = on and Color3.new(1, 1, 1) or Color3.fromRGB(150, 162, 190),
                })
                st.Color = on and Color3.fromRGB(255, 90, 100) or Color3.fromRGB(55, 65, 95)
            end
            painters[#painters + 1] = paint
            paint()
            bind(b.MouseButton1Click, function()
                playClickSound()
                if kind == "click" then
                    clickOn = not clickOn
                else
                    touchOn = not touchOn
                    hookChar(touchOn and LocalPlayer.Character or nil)
                    if touchOn then startWalkFling() else clearTouch() end
                end
                for _, f in ipairs(painters) do pcall(f) end -- iki sekmedeki düğmeler senkron kalsın
            end)
        end
        modeBtn("👆  Tıklayarak (Çift Tık)", 0, 10, "click")
        modeBtn("🤝  Dokunarak", 0.5, 4, "touch")
    end

    -- İsim yazarak hedef seçme (liste + yazı kutusu). Dönen fonksiyon hedef oyuncuyu verir.
    local function resolveTyped(text)
        text = string.lower(text or "")
        if text == "" then return nil end
        local best
        for _, pl in ipairs(Players:GetPlayers()) do
            if pl ~= LocalPlayer then
                local n, d = string.lower(pl.Name), string.lower(pl.DisplayName)
                if n == text or d == text then return pl end
                if not best and (string.find(n, text, 1, true) or string.find(d, text, 1, true)) then best = pl end
            end
        end
        return best
    end

    local function addSelector(page)
        local selRow = baseRow(page, "Frame", 48)
        rowLabel(selRow, "🎯  Oyuncu Seç")
        local selBox = new("TextBox", {
            AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.new(0, 180, 0, 32),
            BackgroundColor3 = Color3.fromRGB(28, 34, 54), Text = "", PlaceholderText = "İsim yaz (örn: hasan)",
            PlaceholderColor3 = Color3.fromRGB(120, 134, 170), TextColor3 = Color3.fromRGB(220, 230, 245),
            TextSize = 12, Font = Enum.Font.GothamBold, ClearTextOnFocus = false, ZIndex = 4,
        }, selRow)
        corner(selBox, 8)
        stroke(selBox, 1, Color3.fromRGB(55, 65, 95), 0.3)
        local selList = new("ScrollingFrame", {
            LayoutOrder = nextOrder(page), Size = UDim2.new(1, 0, 0, 0),
            BackgroundColor3 = Color3.fromRGB(15, 18, 28), BackgroundTransparency = 0.05, BorderSizePixel = 0,
            ScrollBarThickness = 3, CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
            Visible = false, ZIndex = 20,
        }, page)
        corner(selList, 10)
        stroke(selList, 1, Color3.fromRGB(60, 75, 110), 0.2)
        new("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4)}, selList)
        new("UIPadding", {PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6)}, selList)

        local suppress = false
        Settings.PlayerPreviewBind(selList)
        local function hideList()
            selList.Visible = false
            selList.Size = UDim2.new(1, 0, 0, 0)
        end
        local function updateList(filter)
            Settings.PlayerPreview(nil)
            for _, c in ipairs(selList:GetChildren()) do
                if c:IsA("TextButton") then c:Destroy() end
            end
            filter = string.lower(filter or "")
            local count = 0
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer then
                    local nm, dn = string.lower(plr.Name), string.lower(plr.DisplayName)
                    if filter == "" or string.find(nm, filter, 1, true) or string.find(dn, filter, 1, true) then
                        count = count + 1
                        local b = new("TextButton", {
                            Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = Color3.fromRGB(22, 27, 42),
                            BackgroundTransparency = 0.2, AutoButtonColor = false, Text = "", ZIndex = 21,
                        }, selList)
                        corner(b, 8)
                        b.MouseEnter:Connect(function()
                            tween(b, 0.12, {BackgroundTransparency = 0})
                            Settings.PlayerPreview(plr)
                        end)
                        b.MouseLeave:Connect(function()
                            tween(b, 0.18, {BackgroundTransparency = 0.2})
                            Settings.PlayerPreview(nil)
                        end)
                        local av = new("ImageLabel", {
                            Position = UDim2.new(0, 4, 0, 2), Size = UDim2.new(0, 32, 0, 32), BackgroundTransparency = 1, ZIndex = 22,
                            Image = string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=48&h=48", plr.UserId),
                        }, b)
                        pill(av)
                        new("TextLabel", {
                            Position = UDim2.new(0, 42, 0, 0), Size = UDim2.new(1, -45, 1, 0), BackgroundTransparency = 1,
                            Text = plr.DisplayName .. " (@" .. plr.Name .. ")", TextColor3 = Color3.new(1, 1, 1),
                            TextSize = 12, Font = Enum.Font.GothamMedium, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 22,
                        }, b)
                        bind(b.MouseButton1Click, function()
                            playClickSound()
                            suppress = true
                            setText(selBox, plr.Name)
                            suppress = false
                            hideList()
                        end)
                    end
                end
            end
            if count > 0 then
                selList.Visible = true
                tween(selList, 0.2, {Size = UDim2.new(1, 0, 0, math.min(count * 40 + 12, 160))})
            else
                hideList()
            end
        end
        bind(selBox.Focused, function() updateList(selBox.Text) end)
        bind(selBox:GetPropertyChangedSignal("Text"), function()
            if not suppress and selBox:IsFocused() then updateList(selBox.Text) end
        end)
        return function()
            local pl = resolveTyped(selBox.Text)
            if pl and pl.Parent then return pl end
            local g = Settings.GetSelectedTarget and Settings.GetSelectedTarget()
            if g and g.Parent then return g end
            return nil
        end
    end

    -- Özellikler sekmesine eklenen tam fling bölümü
    local function buildFeatures(page)
        createSection(page, "FLING  •  İSİM YAZ / TIKLA / DOKUN")
        local getTarget = addSelector(page)
        createButton(page, "💥  Seçili Oyuncuyu Fırlat (1000x)", function()
            flingTarget(getTarget())
        end)
        addModes(page)
    end

    Settings.FlingKit = {fling = flingTarget, addModes = addModes, addSelector = addSelector, buildFeatures = buildFeatures, isBusy = function() return mm2FlingBusy end}
end)()

---------------------------------------------------------
-- MURDER MYSTERY 2 SEKMESİ  (Troll sekmesinin üstünde)
-- Kendi fonksiyonunun içinde çalışır: ana bölümdeki local sayısını artırmaz.
---------------------------------------------------------
;(function()
    -- MM2 özellikleri SADECE Murder Mystery 2 açıkken yüklenir (başka oyunda sekme bile oluşmaz).
    if not (game.PlaceId == 142823291 or game.GameId == 66654135) then return end
    local MM2Page, MM2Tab = createTab("MM2", "M2")
    pcall(function() MM2Tab.iconLabel.TextSize = 12 end)

    -- MM2 alt kategorileri: Genel / Sheriff / Katil
    local MM2RootPage = MM2Page
    local mm2CategoryPages = {}
    local mm2CategoryButtons = {}
    local mm2ActiveCategory = "GENEL"
    local categoryBar = new("Frame", {
        Name = "MM2CategoryBar",
        Size = UDim2.new(1, 0, 0, 38),
        BackgroundTransparency = 1,
        LayoutOrder = 0,
        ZIndex = 5,
    }, MM2RootPage)
    new("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 6),
    }, categoryBar)

    local function selectMM2Category(name)
        mm2ActiveCategory = name
        for category, frame in pairs(mm2CategoryPages) do
            frame.Visible = (category == name)
        end
        for category, button in pairs(mm2CategoryButtons) do
            local active = category == name
            button.BackgroundColor3 = active and Color3.fromRGB(105, 20, 38) or Color3.fromRGB(30, 18, 23)
            button.TextColor3 = active and Color3.fromRGB(255, 245, 247) or Color3.fromRGB(180, 165, 170)
        end
    end

    for index, name in ipairs({"GENEL", "SHERIFF", "KATİL"}) do
        local button = new("TextButton", {
            Name = "MM2Category_" .. name,
            Size = UDim2.new(1/3, -4, 1, 0),
            BackgroundColor3 = Color3.fromRGB(30, 18, 23),
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Text = name,
            TextColor3 = Color3.fromRGB(180, 165, 170),
            TextSize = 12,
            Font = Enum.Font.GothamBold,
            LayoutOrder = index,
            ZIndex = 6,
        }, categoryBar)
        corner(button, 9)
        mm2CategoryButtons[name] = button

        local frame = new("Frame", {
            Name = "MM2Content_" .. name,
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Visible = false,
            LayoutOrder = 1,
            ZIndex = 3,
        }, MM2RootPage)
        new("UIListLayout", {
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 3),
        }, frame)
        mm2CategoryPages[name] = frame
        bind(button.MouseButton1Click, function()
            playClickSound()
            selectMM2Category(name)
        end)
    end
    selectMM2Category("GENEL")
    local function useMM2Category(name)
        MM2Page = mm2CategoryPages[name]
    end
    useMM2Category("GENEL")

    local RS = game:GetService("ReplicatedStorage")
    local TextService = game:GetService("TextService")

    local ROLE_COLORS = {
        Murderer = Color3.fromRGB(255, 35, 35),   -- katil: kırmızı
        Sheriff  = Color3.fromRGB(45, 130, 255),  -- polis: mavi
        Innocent = Color3.fromRGB(55, 255, 95),   -- masum: yeşil
        Hero     = Color3.fromRGB(255, 225, 40),  -- kahraman: sarı
        Zombie   = Color3.fromRGB(190, 80, 255),  -- zombi: mor
    }
    -- Zombi algılama: rol / takım / NPC adında bu kelimelerden biri geçerse zombi sayılır.
    -- Oyundaki gerçek ad farklıysa buraya ekle.
    local ZOMBIE_WORDS = {"zombie", "zombi", "infected", "undead"}
    local UNDER_DEPTH = 3.5       -- oto farm: coinin kaç stud ALTINDA ilerlenir (yakın = hızlı)
    local TOUCH_RISE = 1.5        -- oto farm: coin alırken coinin kaç stud altına kadar yükselinir
    local LIE_ANGLE = CFrame.Angles(math.rad(90), 0, 0) -- yatay (sırt üstü) yatış duruşu
    local ESCAPE_COOLDOWN = 1.6   -- oto kaçış: iki ışınlanma arası bekleme (sn)

    -- Durum
    local espOn, autoGunOn, escapeOn, farmOn = false, false, false, false
    local escapeDist, farmSpeed = 30, 50
    Settings.FarmTp, Settings.FarmTpSpeed = false, 90   -- turbo süzülme: açık mı / hız (st/sn)
    local coinRetryAt = setmetatable({}, {__mode = "k"})
    local listening = nil
    local roleCache, roleStamp, roleRemote, roleBusy, roleSearchStamp = {}, 0, nil, false, 0
    local espObjs, espTags = {}, {}
    local mapCache, mapStamp, mapDeepStamp = nil, 0, 0
    local lastShot, lastEscape = 0, 0
    local zombieShotOn = true
    local wallOn, wallRedirect = false, nil   -- Duvar arkası vuruş (PREMİUM): açık mı / atış yönlendirici
    local zombieCache, zombieStamp = {}, 0
    local gunAttempts, lastGunObj = 0, nil
    local visited, visitedCount, farmMap, farmDone = {}, 0, nil, false
    local bagNow, bagMax, bagEventSeen = 0, 40, false
    local noCoinTimer, farmStart, noclipConn = nil, nil, nil
    local underground, surfacePos = false, nil -- yerin altında mıyız / yüzeye çıkış noktası

    ---------------------------------------------------------
    -- Genel yardımcılar
    ---------------------------------------------------------
    local function myHRP()
        local c = LocalPlayer.Character
        return c and c:FindFirstChild("HumanoidRootPart")
    end
    local function myHum()
        local c = LocalPlayer.Character
        return c and c:FindFirstChildOfClass("Humanoid")
    end
    local function isAlive(plr)
        local c = plr.Character
        local h = c and c:FindFirstChildOfClass("Humanoid")
        return h ~= nil and h.Health > 0 and c:FindFirstChild("HumanoidRootPart") ~= nil
    end
    local function normRole(r)
        r = string.lower(tostring(r or ""))
        if r:find("murder") then return "Murderer" end
        if r:find("sheriff") then return "Sheriff" end
        if r:find("hero") then return "Hero" end
        if r:find("zombi") or r:find("infect") then return "Zombie" end
        return "Innocent"
    end
    local function charsList()
        local t = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Character then t[#t + 1] = p.Character end
        end
        return t
    end

    -- Roller: oyunun kendi GetPlayerData fonksiyonundan okunur (tüm oyuncuların rolü + ölü mü).
    -- Bulunamazsa eldeki/çantadaki Knife - Gun eşyalarından tahmin edilir.
    local function fetchRoles()
        if roleBusy or os.clock() - roleStamp < 0.4 then return roleCache end
        roleBusy = true
        roleStamp = os.clock()
        pcall(function()
            if (not roleRemote or not roleRemote.Parent) and os.clock() - roleSearchStamp > 4 then
                roleSearchStamp = os.clock()
                for _, d in ipairs(RS:GetDescendants()) do
                    if d.Name == "GetPlayerData" and d:IsA("RemoteFunction") then
                        roleRemote = d
                        break
                    end
                end
            end
            local data
            if roleRemote then
                local ok, res = pcall(function() return roleRemote:InvokeServer() end)
                if ok and type(res) == "table" then data = res end
            end
            local out = {}
            if data then
                for name, info in pairs(data) do
                    if type(info) == "table" then
                        out[tostring(name)] = {
                            Role = normRole(info.Role),
                            Dead = (info.Dead == true) or (info.Killed == true),
                            Raw = info,
                        }
                    end
                end
            else
                for _, p in ipairs(Players:GetPlayers()) do
                    local role = "Innocent"
                    local function scan(c)
                        if not c then return end
                        if c:FindFirstChild("Knife") then role = "Murderer"
                        elseif c:FindFirstChild("Gun") then role = "Sheriff" end
                    end
                    scan(p.Character)
                    scan(p:FindFirstChildOfClass("Backpack"))
                    out[p.Name] = {Role = role, Dead = not isAlive(p)}
                end
            end
            roleCache = out
        end)
        roleBusy = false
        return roleCache
    end

    local function myRole()
        local info = fetchRoles()[LocalPlayer.Name]
        if info then return info.Role, info.Dead end
        return nil, false
    end

    local function findRole(role, excludeSelf)
        for name, info in pairs(fetchRoles()) do
            if info.Role == role and not info.Dead then
                local p = Players:FindFirstChild(name)
                if p and (not excludeSelf or p ~= LocalPlayer) and isAlive(p) then
                    return p
                end
            end
        end
        return nil
    end

    -- Aktif harita: içinde CoinContainer bulunan model
    local function findMap()
        if mapCache and mapCache.Parent and mapCache:FindFirstChild("CoinContainer") then
            return mapCache
        end
        if os.clock() - mapStamp < 1 then return nil end
        mapStamp = os.clock()
        mapCache = nil
        for _, m in ipairs(workspace:GetChildren()) do
            if (m:IsA("Model") or m:IsA("Folder")) and m:FindFirstChild("CoinContainer") then
                mapCache = m
                break
            end
        end
        if not mapCache and os.clock() - mapDeepStamp > 3 then
            mapDeepStamp = os.clock()
            local cc = workspace:FindFirstChild("CoinContainer", true)
            if cc and cc.Parent then mapCache = cc.Parent end
        end
        return mapCache
    end

    local function groundAt(pos)
        local rp = RaycastParams.new()
        rp.FilterType = Enum.RaycastFilterType.Exclude
        rp.FilterDescendantsInstances = charsList()
        local r = workspace:Raycast(pos + Vector3.new(0, 5, 0), Vector3.new(0, -30, 0), rp)
        return r and r.Position or nil
    end

    -- Gövdenin sığacağı boş alan var mı (duvarın / zeminin içine ışınlanmayı engeller)
    local function spaceFree(groundPos)
        local op = OverlapParams.new()
        op.FilterType = Enum.RaycastFilterType.Exclude
        op.FilterDescendantsInstances = charsList()
        local parts = workspace:GetPartBoundsInRadius(groundPos + Vector3.new(0, 3, 0), 2.2, op)
        for _, p in ipairs(parts) do
            if p.CanCollide then return false end
        end
        return true
    end

    local function tpTo(pos)
        local hrp = myHRP()
        if not hrp then return false end
        local hum = myHum()
        if hum and hum.SeatPart then pcall(function() hum.Sit = false end) end
        hrp.CFrame = (hrp.CFrame - hrp.CFrame.Position) + pos
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
        return true
    end

    ---------------------------------------------------------
    -- Lobi / Harita konumları (koordinatlar oyundan okunur)
    ---------------------------------------------------------
    local function getLobbyPos()
        -- 1) Oyundaki gerçek lobi doğuş noktaları
        local spawns = {}
        local lobby = workspace:FindFirstChild("Lobby")
        if lobby then
            for _, d in ipairs(lobby:GetDescendants()) do
                if d:IsA("SpawnLocation") then spawns[#spawns + 1] = d end
            end
        end
        if #spawns == 0 then
            -- 2) Lobide doğduğun yerden kaydedilmiş konum
            local L = Settings.MM2Lobby
            if type(L) == "table" and tonumber(L.x) and tonumber(L.y) and tonumber(L.z) then
                return Vector3.new(L.x, L.y, L.z)
            end
            -- 3) Harita dışındaki herhangi bir SpawnLocation
            local map = findMap()
            for _, d in ipairs(workspace:GetDescendants()) do
                if d:IsA("SpawnLocation") and not (map and d:IsDescendantOf(map)) then
                    spawns[#spawns + 1] = d
                end
            end
        end
        if #spawns > 0 then
            local s = spawns[math.random(1, #spawns)]
            return s.Position + Vector3.new(0, 3.5 + s.Size.Y / 2, 0)
        end
        return nil
    end

    local function lobbyTeleport()
        local pos = getLobbyPos()
        if not pos then return false end
        return tpTo(pos)
    end

    local function mapTeleport()
        local map = findMap()
        if not map then return false end
        local pts = {}
        local sp = map:FindFirstChild("Spawns")
        if sp then
            for _, s in ipairs(sp:GetChildren()) do
                if s:IsA("BasePart") then pts[#pts + 1] = s.Position + Vector3.new(0, 3.5, 0) end
            end
        end
        if #pts == 0 then
            local cc = map:FindFirstChild("CoinContainer")
            if cc then
                for _, c in ipairs(cc:GetChildren()) do
                    if c:IsA("BasePart") then pts[#pts + 1] = c.Position + Vector3.new(0, 3, 0) end
                end
            end
        end
        if #pts == 0 then
            local ok, piv = pcall(function() return map:GetPivot().Position end)
            if ok then pts[1] = piv + Vector3.new(0, 6, 0) end
        end
        if #pts == 0 then return false end
        return tpTo(pts[math.random(1, #pts)])
    end

    -- Lobide doğduğunda konumu otomatik kaydet (yedek lobi koordinatı)
    local function recordLobby()
        task.wait(1.5)
        if not alive then return end
        if findMap() then return end
        local role = myRole()
        if role == "Murderer" or role == "Sheriff" then return end
        local hrp = myHRP()
        if hrp then
            local first = type(Settings.MM2Lobby) ~= "table"
            Settings.MM2Lobby = {x = hrp.Position.X, y = hrp.Position.Y, z = hrp.Position.Z}
            if first then saveConfig() end
        end
    end

    ---------------------------------------------------------
    -- ROL ESP
    ---------------------------------------------------------
    local function clearESP()
        for _, h in pairs(espObjs) do pcall(function() h:Destroy() end) end
        espObjs = {}
        for _, t in pairs(espTags) do pcall(function() t.gui:Destroy() end) end
        espTags = {}
    end

    local function makeHighlight(adornee, parent)
        local h = Instance.new("Highlight")
        h.Name = "EZRAGOX_MM2_ESP"
        h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        h.FillTransparency = 0.5
        h.OutlineTransparency = 0
        h.Adornee = adornee
        h.Parent = parent
        return h
    end

    ---------------------------------------------------------
    -- ESP ETİKETİ (profil fotoğrafı + isim + ▾ menü)
    -- Etiket artık dünyaya yapışık BillboardGui değil; kameradan ekrana izdüşümü
    -- (WorldToViewportPoint) ile her karede başın üstüne konumlanan bir ekran öğesi.
    -- Böylece geniş / gerilmiş ekran ve farklı çözünürlüklerde kayma ya da bozulma olmaz,
    -- boyutu sabit kalır ve tıklanabilir.
    ---------------------------------------------------------
    local tagLayer
    local function getTagLayer()
        if tagLayer and tagLayer.Parent then return tagLayer end
        tagLayer = Instance.new("ScreenGui")
        tagLayer.Name = "EZRAGOX_MM2_TAGS"
        tagLayer.ResetOnSpawn = false
        tagLayer.IgnoreGuiInset = true
        tagLayer.DisplayOrder = 50
        tagLayer.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        tagLayer.Parent = ScreenGui.Parent or CoreGui
        return tagLayer
    end

    local function mk(class, props, parent)
        local o = Instance.new(class)
        for k, v in pairs(props) do o[k] = v end
        o.Parent = parent
        return o
    end
    local function roundIt(o, r)
        local c = Instance.new("UICorner")
        c.CornerRadius = r or UDim.new(1, 0)
        c.Parent = o
        return c
    end

    -- ----- İZLEME (spectate) -----
    local specTarget, specBar
    local function stopSpectate()
        specTarget = nil
        if specBar then pcall(function() specBar:Destroy() end) specBar = nil end
        local cam, hum = workspace.CurrentCamera, myHum()
        if cam and hum then pcall(function() cam.CameraSubject = hum end) end
    end
    local function startSpectate(p)
        if specTarget == p then stopSpectate() return end
        local ch = p.Character
        local hum = ch and ch:FindFirstChildOfClass("Humanoid")
        if not hum then notify("İzleme", "Oyuncunun karakteri bulunamadı.", 2) return end
        if specBar then pcall(function() specBar:Destroy() end) specBar = nil end
        specTarget = p
        pcall(function() workspace.CurrentCamera.CameraSubject = hum end)
        local name = (p.DisplayName and p.DisplayName ~= "") and p.DisplayName or p.Name
        local bar = mk("Frame", {
            Name = "EZRAGOX_SPEC_BAR", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 70),
            Size = UDim2.new(0, 310, 0, 42), BackgroundColor3 = Color3.fromRGB(14, 8, 11), BackgroundTransparency = 0.12,
            BorderSizePixel = 0,
        }, getTagLayer())
        roundIt(bar, UDim.new(0, 12))
        mk("UIStroke", {Thickness = 1.5, Color = Color3.fromRGB(255, 65, 75)}, bar)
        mk("TextLabel", {
            BackgroundTransparency = 1, Position = UDim2.new(0, 14, 0, 0), Size = UDim2.new(1, -112, 1, 0),
            Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = Color3.new(1, 1, 1),
            TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
            Text = "👁️  İzleniyor: " .. name,
        }, bar)
        local stopBtn = mk("TextButton", {
            AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.new(0, 92, 0, 28),
            BackgroundColor3 = Color3.fromRGB(190, 35, 50), BorderSizePixel = 0, Font = Enum.Font.GothamBold,
            TextSize = 13, TextColor3 = Color3.new(1, 1, 1), Text = "✕  Bırak",
        }, bar)
        roundIt(stopBtn, UDim.new(0, 8))
        stopBtn.Activated:Connect(stopSpectate)
        specBar = bar
    end
    task.spawn(function()
        while alive do
            if specTarget then
                if not specTarget.Parent then
                    notify("İzleme", "İzlenen oyuncu oyundan çıktı.", 2)
                    stopSpectate()
                else
                    local ch = specTarget.Character
                    local hum = ch and ch:FindFirstChildOfClass("Humanoid")
                    local cam = workspace.CurrentCamera
                    if hum and cam and cam.CameraSubject ~= hum then pcall(function() cam.CameraSubject = hum end) end
                end
            end
            task.wait(0.2)
        end
        stopSpectate()
        if tagLayer then pcall(function() tagLayer:Destroy() end) end
    end)

    -- ----- Açık menü yönetimi -----
    local openMenu
    local function closeMenu()
        if openMenu then pcall(function() openMenu.Visible = false end) openMenu = nil end
    end
    bind(UserInputService.InputBegan, function(input, gpe)
        if gpe then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            closeMenu()
        end
    end)

    -- Oyuncunun başının üstünde: yuvarlak profil fotoğrafı + rol renginde isim + ▾ menü
    local function makeNameTag(p, ch, col)
        local head = ch:FindFirstChild("Head") or ch:FindFirstChild("HumanoidRootPart")
        if not head then return nil end
        local name = (p.DisplayName and p.DisplayName ~= "") and p.DisplayName or p.Name
        local textW = 80
        pcall(function()
            textW = TextService:GetTextSize(name, 12, Enum.Font.GothamBold, Vector2.new(400, 26)).X
        end)
        local width = math.clamp(math.floor(textW) + 44, 90, 260)

        local root = mk("Frame", {
            Name = "EZRAGOX_MM2_TAG", AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.new(0, width, 0, 30),
            BackgroundColor3 = Color3.fromRGB(8, 8, 12), BackgroundTransparency = 0.3, BorderSizePixel = 0,
            Visible = false,
        }, getTagLayer())
        roundIt(root)
        local ps = mk("UIStroke", {Thickness = 1.1, Color = col}, root)

        local avatar = mk("ImageLabel", {
            AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 4, 0.5, 0), Size = UDim2.new(0, 22, 0, 22),
            BackgroundColor3 = Color3.fromRGB(30, 30, 38), BorderSizePixel = 0,
            Image = string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", p.UserId),
        }, root)
        roundIt(avatar)
        local avStroke = mk("UIStroke", {Thickness = 1.3, Color = col}, avatar)

        local label = mk("TextLabel", {
            BackgroundTransparency = 1, Position = UDim2.new(0, 31, 0, 0), Size = UDim2.new(1, -38, 1, 0),
            Font = Enum.Font.GothamBold, TextSize = 12, Text = name, TextColor3 = col,
            TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
        }, root)

        -- Nokta kaldırıldı: isme (veya profil fotoğrafına) basınca menü açılır.
        -- Görünmez tam boy buton etiketin üstünü kaplar; menü (ZIndex 5) bunun üstünde kalır.
        local arrow = mk("TextButton", {
            Position = UDim2.new(0, 0, 0, 0), Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1, BorderSizePixel = 0, Text = "", AutoButtonColor = false,
            ZIndex = 2,
        }, root)

        local menu = mk("Frame", {
            Name = "Menu", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 1, 6), Size = UDim2.new(0, 178, 0, 106),
            BackgroundColor3 = Color3.fromRGB(14, 8, 11), BackgroundTransparency = 0.05, BorderSizePixel = 0,
            Visible = false, ZIndex = 5,
        }, root)
        roundIt(menu, UDim.new(0, 12))
        local ms = mk("UIStroke", {Thickness = 1.5, Color = col}, menu)

        local function menuButton(y, text, onClick)
            local b = mk("TextButton", {
                Position = UDim2.new(0, 6, 0, y), Size = UDim2.new(1, -12, 0, 30), BackgroundColor3 = Color3.fromRGB(30, 20, 25),
                BorderSizePixel = 0, Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = Color3.new(1, 1, 1),
                Text = text, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6, AutoButtonColor = true,
            }, menu)
            roundIt(b, UDim.new(0, 8))
            mk("UIPadding", {PaddingLeft = UDim.new(0, 10)}, b)
            b.Activated:Connect(function()
                closeMenu()
                pcall(onClick)
            end)
            return b
        end

        menuButton(6, "🌀  Fling", function()
            local f = Settings.MM2FlingPlayer
            if f then f(p) else notify("Fling", "Fling özelliği yüklenemedi.", 2) end
        end)
        menuButton(38, "📍  Yanına Işınlan", function()
            local tc = p.Character
            local thrp = tc and tc:FindFirstChild("HumanoidRootPart")
            if not thrp then notify("Işınlan", "Oyuncunun karakteri bulunamadı.", 2) return end
            tpTo(thrp.Position - thrp.CFrame.LookVector * 3 + Vector3.new(0, 1.5, 0))
        end)
        local specBtn = menuButton(70, "👁️  İzle", function() startSpectate(p) end)

        arrow.Activated:Connect(function()
            if openMenu == menu then closeMenu() return end
            closeMenu()
            specBtn.Text = (specTarget == p) and "👁️  İzlemeyi Bırak" or "👁️  İzle"
            menu.Visible = true
            openMenu = menu
        end)

        return {gui = root, head = head, pillStroke = ps, avatarStroke = avStroke, label = label, arrow = arrow, menuStroke = ms, menu = menu, baseName = name, shownText = name}
    end

    -- Her karede etiketleri kafanın üstüne yerleştir (ekran-uzayı; çözünürlükten bağımsız)
    bind(RunService.RenderStepped, function()
        if not next(espTags) then return end
        local cam = workspace.CurrentCamera
        if not cam then return end
        for _, t in pairs(espTags) do
            local head = t.head
            if head and head.Parent and t.gui.Parent then
                local top = head.Position + Vector3.new(0, head.Size.Y / 2 + 0.7, 0)
                local v, onScreen = cam:WorldToViewportPoint(top)
                if onScreen and v.Z > 0 and v.Z < 2000 then
                    t.gui.Visible = true
                    t.gui.Position = UDim2.fromOffset(math.floor(v.X + 0.5), math.floor(v.Y + 0.5) - 4)
                else
                    if t.gui.Visible then t.gui.Visible = false end
                    if openMenu == t.menu then closeMenu() end
                end
            end
        end
    end)

    local PK = {}  -- ESP yardımcıları (yerel değişken sınırı için tek tabloda)
    -- Katilin o an elinde tuttuğu eşyanın (bıçak / skin / özellik) adı
    function PK.heldItemName(ch)
        if not ch then return nil end
        local tool = ch:FindFirstChildOfClass("Tool")
        if not tool then return nil end
        local nm
        pcall(function()
            nm = tool:GetAttribute("DisplayName") or tool:GetAttribute("ItemName") or tool:GetAttribute("SkinName")
        end)
        if type(nm) ~= "string" or nm == "" then
            local sv = tool:FindFirstChild("ItemName") or tool:FindFirstChild("DisplayName")
            if sv and sv:IsA("StringValue") and sv.Value ~= "" then nm = sv.Value end
        end
        if type(nm) ~= "string" or nm == "" then nm = tool.Name end
        return nm
    end

    -- Katilin kuşandığı GÜÇ (perk / ability): oyunun oyuncu verisinden, özelliklerinden
    -- ve oyuncu/karakter altındaki değer nesnelerinden "perk / power / ability / güç" adlı
    -- kayıtlar aranır. Bulunamazsa etikette güç yazısı gösterilmez.
    PK.PATTERNS = {"perk", "power", "abilit", "güç"}
    function PK.isPerkKey(k)
        k = string.lower(tostring(k))
        for _, pat in ipairs(PK.PATTERNS) do
            if string.find(k, pat, 1, true) then return true end
        end
        return false
    end
    function PK.perkValueText(v)
        local tv = type(v)
        if tv == "string" then return v ~= "" and v or nil end
        if tv == "table" then
            local out = {}
            for k, val in pairs(v) do
                if type(val) == "string" and val ~= "" then out[#out + 1] = val
                elseif val == true and type(k) == "string" then out[#out + 1] = k
                elseif type(val) == "table" then
                    local nm = val.Name or val.DisplayName or val.Id
                    if type(nm) == "string" and nm ~= "" then out[#out + 1] = nm end
                end
                if #out >= 4 then break end
            end
            if #out > 0 then table.sort(out) return table.concat(out, ", ") end
        end
        return nil
    end
    function PK.perkFromInstance(inst)
        if not inst then return nil end
        local found
        pcall(function()
            for k, v in pairs(inst:GetAttributes()) do
                if PK.isPerkKey(k) then
                    local t = PK.perkValueText(v)
                    if t then found = t return end
                end
            end
        end)
        if found then return found end
        pcall(function()
            for _, c in ipairs(inst:GetChildren()) do
                if PK.isPerkKey(c.Name) then
                    if c:IsA("StringValue") and c.Value ~= "" then found = c.Value return end
                    if c:IsA("Folder") or c:IsA("Configuration") then
                        local names = {}
                        for _, cc in ipairs(c:GetChildren()) do
                            names[#names + 1] = (cc:IsA("StringValue") and cc.Value ~= "") and cc.Value or cc.Name
                            if #names >= 4 then break end
                        end
                        if #names > 0 then found = table.concat(names, ", ") return end
                    end
                end
            end
        end)
        return found
    end
    -- Oyundaki güçlerin (perk) Türkçe adları: Ninja, Parlaklık, Tuzak, Sahte Silah,
    -- Haste, Koşma, Hayalet, X-Ray. İngilizce / farklı yazılmış adlar da eşleştirilir.
    PK.TR = {
        {"Ninja", {"ninja"}},
        {"Parlaklık", {"shimmer", "glow", "shine", "parlak"}},
        {"Tuzak", {"trap", "tuzak"}},
        {"Sahte Silah", {"fakegun", "fake", "sahte"}},
        {"Haste", {"haste"}},
        {"Koşma", {"sprint", "run", "koş", "kosma"}},
        {"Hayalet", {"ghost", "hayalet"}},
        {"X-Ray", {"xray", "x-ray", "x_ray"}},
    }
    function PK.perkTR(text)
        if type(text) ~= "string" then return nil end
        local out, seen = {}, {}
        for part in string.gmatch(text, "[^,]+") do
            local low = string.lower((string.gsub(part, "^%s*(.-)%s*$", "%1")))
            local nice = nil
            for _, e in ipairs(PK.TR) do
                for _, key in ipairs(e[2]) do
                    if string.find(low, key, 1, true) then nice = e[1] break end
                end
                if nice then break end
            end
            nice = nice or (string.gsub(part, "^%s*(.-)%s*$", "%1"))
            if nice ~= "" and not seen[nice] then seen[nice] = true out[#out + 1] = nice end
        end
        return #out > 0 and table.concat(out, ", ") or nil
    end
    function PK.equippedPerk(p, info, ch)
        if info and type(info.Raw) == "table" then
            for k, v in pairs(info.Raw) do
                if PK.isPerkKey(k) then
                    local t = PK.perkValueText(v)
                    if t then return t end
                end
            end
        end
        return PK.perkFromInstance(p) or PK.perkFromInstance(ch)
    end

    -- Teşhis: katilin oyun verisinde / oyuncu nesnelerinde ne var, F9 konsoluna yazar
    function PK.dumpValue(v, depth, maxDepth, lines, prefix)
        if type(v) == "table" and depth < maxDepth then
            local n = 0
            for k, val in pairs(v) do
                n = n + 1
                if n > 25 then lines[#lines + 1] = prefix .. "  ..." break end
                if type(val) == "table" then
                    lines[#lines + 1] = prefix .. tostring(k) .. " = {"
                    PK.dumpValue(val, depth + 1, maxDepth, lines, prefix .. "  ")
                    lines[#lines + 1] = prefix .. "}"
                else
                    lines[#lines + 1] = prefix .. tostring(k) .. " = " .. tostring(val)
                end
            end
        end
    end
    function PK.perkDiagnose()
        local roles = fetchRoles()
        local m = findRole("Murderer", false)
        if not m then notify("Güç Teşhisi", "Katil bulunamadı (tur başlamış olmalı).", 3) return end
        local lines = {"[EZRAGOX] Katil: " .. m.Name}
        local info = roles[m.Name]
        lines[#lines + 1] = "-- Oyun oyuncu verisi (GetPlayerData):"
        if info and type(info.Raw) == "table" then PK.dumpValue(info.Raw, 0, 3, lines, "  ") else lines[#lines + 1] = "  (yok)" end
        lines[#lines + 1] = "-- Oyuncu özellikleri (Attributes):"
        pcall(function() for k, v in pairs(m:GetAttributes()) do lines[#lines + 1] = "  " .. k .. " = " .. tostring(v) end end)
        lines[#lines + 1] = "-- Oyuncu altındaki nesneler:"
        pcall(function() for _, c in ipairs(m:GetChildren()) do lines[#lines + 1] = "  " .. c.ClassName .. ": " .. c.Name end end)
        lines[#lines + 1] = "-- Karakter özellikleri:"
        pcall(function() if m.Character then for k, v in pairs(m.Character:GetAttributes()) do lines[#lines + 1] = "  " .. k .. " = " .. tostring(v) end end end)
        lines[#lines + 1] = "-- Bulunan güç: " .. tostring(PK.perkTR(PK.equippedPerk(m, info, m.Character)))
        warn(table.concat(lines, "\n"))
        notify("Güç Teşhisi", "Rapor F9 konsoluna yazıldı. Bulunan güç: " .. tostring(PK.perkTR(PK.equippedPerk(m, info, m.Character))), 4)
    end
    Settings.MM2PerkDiagnose = PK.perkDiagnose

    -- Etiket yazısını günceller; yazı değişince etiket genişliği de yazıya göre ayarlanır
    function PK.setTagText(tag, text)
        if not tag or tag.shownText == text then return end
        tag.shownText = text
        tag.label.Text = text
        local textW = 80
        pcall(function()
            textW = TextService:GetTextSize(text, 12, Enum.Font.GothamBold, Vector2.new(600, 26)).X
        end)
        local width = math.clamp(math.floor(textW) + 44, 90, 380)
        tag.gui.Size = UDim2.new(0, width, 0, 30)
    end

    local function applyESP()
        local roles = fetchRoles()
        local hasRound = false
        for _, info in pairs(roles) do
            if (info.Role == "Murderer" or info.Role == "Zombie") and not info.Dead then hasRound = true break end
        end
        if not hasRound then clearESP() return end

        local seen = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                local info = roles[p.Name]
                local ch = p.Character
                if info and not info.Dead and ch and ch:FindFirstChild("HumanoidRootPart") then
                    local col = ROLE_COLORS[info.Role] or ROLE_COLORS.Innocent
                    local h = espObjs[p]
                    if not h or not h.Parent or h.Adornee ~= ch then
                        if h then pcall(function() h:Destroy() end) end
                        h = makeHighlight(ch, ch)
                        espObjs[p] = h
                    end
                    if h.FillColor ~= col then h.FillColor = col end
                    if h.OutlineColor ~= col then h.OutlineColor = col end

                    -- İsim etiketi (rol rengi değişirse etiket de güncellenir)
                    local tag = espTags[p]
                    if not tag or not tag.gui.Parent or tag.head.Parent ~= ch then
                        if tag then pcall(function() tag.gui:Destroy() end) end
                        tag = makeNameTag(p, ch, col)
                        espTags[p] = tag
                    end
                    if tag and tag.label.TextColor3 ~= col then
                        tag.pillStroke.Color = col
                        tag.avatarStroke.Color = col
                        tag.label.TextColor3 = col
                        if tag.arrow then tag.arrow.TextColor3 = col end
                        if tag.menuStroke then tag.menuStroke.Color = col end
                    end
                    -- Katilin ismine, elindeki eşyayı da ekle
                    if tag then
                        if info.Role == "Murderer" then
                            local perk = PK.perkTR(PK.equippedPerk(p, info, ch))
                            PK.setTagText(tag, perk and (tag.baseName .. "  •  ⚡ " .. perk) or tag.baseName)
                        else
                            PK.setTagText(tag, tag.baseName)
                        end
                    end
                    seen[p] = true
                end
            end
        end
        for p, h in pairs(espObjs) do
            if not seen[p] then
                pcall(function() h:Destroy() end)
                espObjs[p] = nil
            end
        end
        for p, t in pairs(espTags) do
            if not seen[p] then
                pcall(function() t.gui:Destroy() end)
                espTags[p] = nil
            end
        end
    end

    ---------------------------------------------------------
    -- KESKİN VURUŞ (katil nerede olursa olsun ateş)
    ---------------------------------------------------------
    local function getPingSeconds()
        local ok, v = pcall(function() return Stats.Network.ServerStatsItem["Data Ping"]:GetValue() end)
        return math.clamp(((ok and v) or 100) / 1000, 0.05, 0.25)
    end

    local function findGun()
        local ch = LocalPlayer.Character
        local g = ch and ch:FindFirstChild("Gun")
        if g and g:IsA("Tool") then return g end
        local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
        g = bp and bp:FindFirstChild("Gun")
        if g and g:IsA("Tool") then return g end
        return nil
    end

    -- TEŞHİS: silahın üstündeki "CantShoot" tabelası (BillboardGui) görünür olunca oyunun
    -- kendisinin gösterdiği yazıyı bize de bildirim olarak gösterir. Bu bize ateşin neden
    -- reddedildiğini (mermi yok, bekleme süresi, menzil dışı, engel vb.) oyunun kendi ağzından
    -- gösterir; duvar arkası vuruşun neden tutmadığını anlamaya yardımcı olur.
    local watchedCantShoot = setmetatable({}, {__mode = "k"})
    local function watchCantShoot(gun)
        if not gun or watchedCantShoot[gun] then return end
        local cs = gun:FindFirstChild("CantShoot")
        if not (cs and cs:IsA("BillboardGui")) then return end
        local lbl = cs:FindFirstChild("TextLabel")
        watchedCantShoot[gun] = true
        local function relay()
            if cs.Enabled ~= false and cs.Visible and lbl and lbl.Text and lbl.Text ~= "" then
                pcall(notifyTop, "🚫 Oyun: " .. lbl.Text, 3)
            end
        end
        bind(cs:GetPropertyChangedSignal("Visible"), relay)
        bind(cs:GetPropertyChangedSignal("Enabled"), relay)
        if lbl then bind(lbl:GetPropertyChangedSignal("Text"), relay) end
    end
    task.spawn(function()
        while alive do
            pcall(function()
                local g = findGun()
                if g then watchCantShoot(g) end
            end)
            task.wait(1)
        end
    end)

    local function callRemote(r, ...)
        if r:IsA("RemoteFunction") then
            return r:InvokeServer(...)
        elseif r:IsA("RemoteEvent") then
            return r:FireServer(...)
        end
        error("remote değil")
    end

    local lastShootWarn = 0
    local function shootWarn(msg)
        if os.clock() - lastShootWarn < 2 then return end
        lastShootWarn = os.clock()
        pcall(notifyTop, "🔫 " .. msg, 6, 560)
    end

    local function isRemote(o)
        return o ~= nil and (o:IsA("RemoteFunction") or o:IsA("RemoteEvent"))
    end

    -- Silahın içindeki ateş remote'larını bul (oyun yerini değiştirse de isimle arar).
    -- Bazı basit silah kitleri (ör. senin silahın) doğrudan Gun.Shoot adında bir RemoteEvent kullanır.
    local function findGunRemotes(gun)
        local ks = gun:FindFirstChild("KnifeServer")
        local shoot = ks and ks:FindFirstChild("ShootGun")
        if not isRemote(shoot) then
            local d = gun:FindFirstChild("ShootGun", true)
            shoot = isRemote(d) and d or nil
        end
        local kl = gun:FindFirstChild("KnifeLocal")
        local cb = kl and kl:FindFirstChild("CreateBeam")
        local beam = cb and cb:FindFirstChild("RemoteFunction")
        if not isRemote(beam) then
            local c2 = gun:FindFirstChild("CreateBeam", true)
            if isRemote(c2) then
                beam = c2
            elseif c2 then
                beam = c2:FindFirstChildWhichIsA("RemoteFunction") or c2:FindFirstChildWhichIsA("RemoteEvent")
            else
                beam = nil
            end
        end
        local direct = gun:FindFirstChild("Shoot")
        if not isRemote(direct) then
            direct = gun:FindFirstChild("Shoot", true)
            if not isRemote(direct) then direct = nil end
        end
        return shoot, beam, direct
    end

    -- Oyunun GERÇEK ateş çağrısını öğren: silahla bir kez normal ateş edince, çağrının
    -- argümanları (anahtar kelimeler dahil) kaydedilir ve sonra konum değiştirilerek tekrarlanır.
    -- (Yalnızca executor hookmetamethod destekliyorsa çalışır; kendi çağrılarımız kaydedilmez.)
    local SFX = {sel = math.clamp(tonumber(Settings.MM2GunSound) or 0, 0, 5), headshotOn = true, lastShot = 0, lastHead = 0, lastSound = 0, inBurst = false, burstPlayed = false, burstFx = false}
    -- Silah yeniden dolarken (mermi doldurma) ses / mermi izi çıkmasın: iki atış efekti arası en az bu kadar sn.
    -- Oyunda silahın dolma süresi daha kısa/uzunsa bu değeri değiştir.
    Settings.MM2FxCooldown = 1.8
    local learned = {}      -- ["ShootGun" | "CreateBeam"] = {args = paketlenmiş argümanlar, t = zaman}
    local hookReady = false
    pcall(function()
        if hookmetamethod and getnamecallmethod and checkcaller then
            local old
            local function handler(self, ...)
                local method = getnamecallmethod()
                local mod = nil
                if alive and (method == "FireServer" or method == "InvokeServer") and not checkcaller() then
                    local ok, nm, pn = pcall(function()
                        return self.Name, self.Parent and self.Parent.Name
                    end)
                    if ok then
                        local key = (nm == "ShootGun" and "ShootGun") or (nm == "Shoot" and "Shoot")
                            or (pn == "CreateBeam" and "CreateBeam") or nil
                        if not key and type(nm) == "string" and string.find(string.lower(nm), "throw", 1, true) then
                            -- Bıçak atma çağrısı: argümanlar öğrenilir (ses/efekt tetiklenmez)
                            learned["Throw"] = {args = table.pack(...), t = os.clock()}
                        end
                        if key then
                            learned[key] = {args = table.pack(...), t = os.clock()}
                            if SFX.shot then task.defer(SFX.shot) end -- oyuncunun gerçek atışı
                            -- DUVAR ARKASI VURUŞ (premium): gerçek atışın hedef noktasını katilin konumuyla değiştir
                            if (wallOn or SFX.shootLeftOn) and wallRedirect then
                                local okR, r = pcall(wallRedirect, key, table.pack(...))
                                if okR and r then mod = r SFX.lastRedirect = os.clock() end
                            end
                        end
                    end
                end
                if mod then
                    -- Araya giren başka çağrılar namecall yöntemini bozmasın
                    if setnamecallmethod then pcall(setnamecallmethod, method) end
                    return old(self, table.unpack(mod, 1, mod.n))
                end
                return old(self, ...)
            end
            old = hookmetamethod(game, "__namecall", newcclosure and newcclosure(handler) or handler)
            hookReady = true
        end
    end)

    -- Öğrenilmiş çağrıdaki konum argümanlarını günceller:
    -- SON Vector3/CFrame = hedef nokta; ondan önce bir tane daha varsa o = çıkış noktası (şu anki konum).
    local function withPos(args, pos, origin)
        local idxs = {}
        for i = 1, args.n do
            local t = typeof(args[i])
            if t == "Vector3" or t == "CFrame" then idxs[#idxs + 1] = i end
        end
        local out = {n = args.n}
        for i = 1, args.n do out[i] = args[i] end
        local function put(i, p)
            out[i] = (typeof(args[i]) == "CFrame") and CFrame.new(p) or p
        end
        if #idxs >= 1 then put(idxs[#idxs], pos) end
        if #idxs >= 2 and origin then put(idxs[1], origin) end
        return out
    end

    -- Verilen çağrıları (neredeyse) aynı anda gönderir; (başarılı mı, hata listesi) döndürür
    local function runAttempts(list)
        local pending, okAny, errs = #list, false, {}
        for _, a in ipairs(list) do
            task.spawn(function()
                local ok, err = pcall(function()
                    if a.remote:IsA("RemoteFunction") then
                        return a.remote:InvokeServer(table.unpack(a.args, 1, a.args.n))
                    end
                    return a.remote:FireServer(table.unpack(a.args, 1, a.args.n))
                end)
                if ok then okAny = true else errs[#errs + 1] = tostring(err) end
                pending = pending - 1
            end)
        end
        local t0 = os.clock()
        while pending > 0 and os.clock() - t0 < 0.8 do task.wait() end
        -- Süre doldu ama hata gelmediyse sunucu yanıtı bekleniyor demektir: atılmış say
        if pending > 0 and #errs == 0 then okAny = true end
        return okAny, errs
    end

    local function dumpGun(gun)
        local lines = {}
        for _, d in ipairs(gun:GetDescendants()) do
            lines[#lines + 1] = d.ClassName .. "   " .. d:GetFullName()
        end
        warn("[EZRAGOX] Silahın içeriği:\n" .. table.concat(lines, "\n"))
    end

    -- Hedef konumu doğrudan sunucuya gönderir: kamera DÖNMEZ, fare konumu KULLANILMAZ.
    local function fireGunAt(pos)
        local gun = findGun()
        if not gun then
            shootWarn("Silahın yok (polis/kahraman değilsin).")
            return false
        end
        local ch = LocalPlayer.Character
        local hum = myHum()
        if hum and gun.Parent ~= ch then
            local t0 = os.clock()
            while gun.Parent ~= ch and os.clock() - t0 < 1.2 and alive do
                pcall(function() hum:EquipTool(gun) end)
                local t1 = os.clock()
                while gun.Parent ~= ch and os.clock() - t1 < 0.25 do task.wait() end
            end
            task.wait(0.08) -- silahın sunucu betiği hazır olsun
        end
        if not gun.Parent then return false end
        -- Nişan noktası fonksiyon olarak verildiyse ŞİMDİ (ele alma beklemesinden sonra, gönderim
        -- anında) yeniden hesapla: bekleme sırasında hareket eden hedef için eski nokta bayatlar.
        if type(pos) == "function" then
            local okp, np = pcall(pos)
            if not okp or typeof(np) ~= "Vector3" then return false end
            pos = np
        end
        local shootRemote, beamRemote, directRemote = findGunRemotes(gun)
        local handle = gun:FindFirstChild("Handle")
        local origin = (handle and handle:IsA("BasePart") and handle.Position)
            or (myHRP() and myHRP().Position) or pos
        if not shootRemote and not beamRemote and not directRemote then
            pcall(dumpGun, gun)
            shootWarn("Silahta ateş remote'u bulunamadı. F9 konsoluna silah içeriğini yazdım.")
            return false
        end

        -- Aynı tuş basışının tekrar denemeleri (silah dolarken) ses / mermi izi ÜRETMEZ; yalnızca ilk ateş üretir
        local fxOk = true
        if SFX.inBurst then
            if SFX.burstFx then fxOk = false else SFX.burstFx = true end
        end
        if fxOk and Settings.PXShot then pcall(Settings.PXShot, origin, pos) end -- mermi izi / efekt tetikleyici
        local errs = {}
        -- 1) Öğrenilmiş gerçek çağrı varsa onu kullan (silahla bir kez normal ateş edince kaydedilir)
        local remoteByKey = {ShootGun = shootRemote, CreateBeam = beamRemote, Shoot = directRemote}
        local list = {}
        for key, rec in pairs(learned) do
            local r = remoteByKey[key]
            if r then list[#list + 1] = {remote = r, args = withPos(rec.args, pos, origin), t = rec.t} end
        end
        table.sort(list, function(a, b) return a.t < b.t end)
        if #list > 0 then
            local ok, e = runAttempts(list)
            if ok then
                if SFX.shot and fxOk then task.defer(SFX.shot, true) end
                return true
            end
            errs = e
        end
        -- 2) Bilinen varsayılan çağrılar (öğrenilmiş veri yoksa ilk denemeler)
        local defaults = {}
        if shootRemote then defaults[#defaults + 1] = {remote = shootRemote, args = table.pack(1, pos, "AH")} end
        if beamRemote then defaults[#defaults + 1] = {remote = beamRemote, args = table.pack(1, pos, "AH2")} end
        if directRemote then
            -- Basit silah kitlerinde genelde tek argüman: vurulan nokta
            -- Yeni MM2 silahı: Gun.Shoot:FireServer(çıkışCFrame, hedefCFrame)
            defaults[#defaults + 1] = {remote = directRemote, args = table.pack(CFrame.new(origin), CFrame.new(pos))}
            defaults[#defaults + 1] = {remote = directRemote, args = table.pack(origin, pos)}
            defaults[#defaults + 1] = {remote = directRemote, args = table.pack(pos)}
            defaults[#defaults + 1] = {remote = directRemote, args = table.pack(pos, workspace)}
        end
        local ok, e = runAttempts(defaults)
        if ok then
            if SFX.shot and fxOk then task.defer(SFX.shot, true) end
            -- RemoteEvent yanlış argümanla da hata vermez; gerçek çağrı öğrenilmediyse uyar
            if hookReady and next(learned) == nil then
                shootWarn("Tahmini ateş gönderildi. Vurmazsa silahla bir kez normal ateş et; script gerçek çağrıyı öğrenip düzeltir.")
            end
            return true
        end
        for _, x in ipairs(e) do errs[#errs + 1] = x end

        pcall(dumpGun, gun)
        warn("[EZRAGOX] Ateş hataları:\n" .. table.concat(errs, "\n"))
        local first = string.sub(tostring(errs[1] or "bilinmiyor"), 1, 70)
        if hookReady and next(learned) == nil then
            shootWarn("Ateş edilemedi. Silahla bir kez normal ateş et, script öğrensin. (" .. first .. ")")
        else
            shootWarn("Ateş edilemedi: " .. first)
        end
        return false
    end

    local function nameLooksZombie(name)
        name = string.lower(tostring(name or ""))
        for _, w in ipairs(ZOMBIE_WORDS) do
            if string.find(name, w, 1, true) then return true end
        end
        return false
    end

    local function targetPartOf(ch)
        return ch:FindFirstChild("HumanoidRootPart") or ch:FindFirstChild("Torso")
            or ch:FindFirstChild("UpperTorso") or ch.PrimaryPart or ch:FindFirstChildWhichIsA("BasePart")
    end

    -- Zombiler: (1) rolü/takımı zombi olan oyuncular, (2) adında zombi geçen NPC modeller
    local function listZombies()
        if os.clock() - zombieStamp < 1.0 then return zombieCache end
        zombieStamp = os.clock()
        local out = {}
        local playerChars = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Character then playerChars[p.Character] = true end
        end
        local roles = fetchRoles()
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character and isAlive(p) then
                local info = roles[p.Name]
                local teamHit = p.Team ~= nil and nameLooksZombie(p.Team.Name)
                if (info and info.Role == "Zombie" and not info.Dead) or teamHit then
                    out[#out + 1] = p.Character
                end
            end
        end
        for _, d in ipairs(workspace:GetDescendants()) do
            if d:IsA("Humanoid") and d.Health > 0 then
                local model = d.Parent
                if model and model:IsA("Model") and not playerChars[model] then
                    local hit = nameLooksZombie(model.Name)
                    if not hit and model.Parent and model.Parent ~= workspace then
                        hit = nameLooksZombie(model.Parent.Name)
                    end
                    if hit then out[#out + 1] = model end
                end
            end
        end
        zombieCache = out
        return out
    end

    -- Hedef seçimi: katil (ve açıksa zombiler) arasından en yakın canlı olan
    local function pickTarget()
        local me = myHRP()
        if not me then return nil end
        local cands = {}
        local m = findRole("Murderer", true)
        if not m then
            -- Rol bilgisi henüz gelmediyse hemen yenile ve tekrar dene
            roleStamp = 0
            m = findRole("Murderer", true)
        end
        if not m then
            -- Yedek: elinde/çantasında bıçak olan canlı oyuncu katildir
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer and p.Character and isAlive(p) then
                    local bp = p:FindFirstChildOfClass("Backpack")
                    if p.Character:FindFirstChild("Knife") or (bp and bp:FindFirstChild("Knife")) then m = p break end
                end
            end
        end
        if m and m.Character then cands[#cands + 1] = m.Character end
        if zombieShotOn then
            for _, z in ipairs(listZombies()) do cands[#cands + 1] = z end
        end
        local bestPart, bestHum, bestD
        for _, ch in ipairs(cands) do
            local hum = ch:FindFirstChildOfClass("Humanoid")
            local part = targetPartOf(ch)
            if part and hum and hum.Health > 0 then
                local d = (part.Position - me.Position).Magnitude
                if not bestD or d < bestD then bestPart, bestHum, bestD = part, hum, d end
            end
        end
        return bestPart, bestHum
    end

    -- Nişan noktası: hedefin MERMİ ULAŞTIĞINDA bulunacağı yer.
    --  • Hız, hedefin son ~0.2 sn'lik gerçek konum geçmişinden ölçülür (uzak oyuncularda
    --    AssemblyLinearVelocity titrek / gecikmeli olabildiği için bununla harmanlanır).
    --  • Öngörü süresi = ping + küçük arayüz/interpolasyon payı; "Nişan Öngörüsü" kaydırıcısıyla ayarlanır.
    --  • Havadaysa yerçekimi de hesaba katılır; yerdeyken dikey hız yok sayılır.
    --  • Hedef durmuşsa (ya da neredeyse) öngörü eklenmez → duran hedefi asla ıskalamaz.
    --  • Yatay öngörü mesafesi sınırlıdır (ani yön değiştirince aşırı ileri nişan almasın).
    SFX.leadMul = 1
    SFX.hist = setmetatable({}, {__mode = "k"})
    local function recordPos(part)
        local h = SFX.hist[part]
        if not h then h = {} SFX.hist[part] = h end
        local now = os.clock()
        h[#h + 1] = {t = now, p = part.Position}
        while #h > 0 and now - h[1].t > 0.45 do table.remove(h, 1) end
    end
    bind(RunService.Heartbeat, function()
        for _, pl in ipairs(Players:GetPlayers()) do
            if pl ~= LocalPlayer then
                local ch = pl.Character
                local part = ch and targetPartOf(ch)
                if part then recordPos(part) end
            end
        end
    end)
    local function measuredVelocity(part)
        local h = SFX.hist[part]
        if not h or #h < 3 then return nil end
        local newest = h[#h]
        local ref
        for i = #h - 1, 1, -1 do
            ref = h[i]
            if newest.t - h[i].t >= 0.2 then break end
        end
        local dt = newest.t - ref.t
        if dt < 0.07 then return nil end
        return (newest.p - ref.p) / dt
    end
    local function aimPoint(part, hum)
        local grounded = hum.FloorMaterial ~= Enum.Material.Air
        local va = part.AssemblyLinearVelocity
        local vm = measuredVelocity(part)
        local v
        if vm and va.Magnitude > 1 then v = vm * 0.65 + va * 0.35
        elseif vm then v = vm
        else v = va end
        local flat = Vector3.new(v.X, 0, v.Z)
        if flat.Magnitude < 1.2 then flat = Vector3.zero end
        local t = (getPingSeconds() + 0.06) * (SFX.leadMul or 1)
        local lead = flat * t
        if lead.Magnitude > 16 then lead = lead.Unit * 16 end
        local dy = 0
        if not grounded then
            dy = v.Y * t - 0.5 * workspace.Gravity * t * t
            dy = math.clamp(dy, -6, 6)
        end
        return part.Position + lead + Vector3.new(0, dy, 0)
    end

    -- Gerçek görüş hattı var mı? (yalnızca duvar/engel kontrolü; oyuncu karakterleri yok sayılır)
    local function hasLineOfSight(origin, targetPos)
        local dir = targetPos - origin
        local dist = dir.Magnitude
        if dist < 1 then return true end
        local rp = RaycastParams.new()
        rp.FilterType = Enum.RaycastFilterType.Exclude
        rp.IgnoreWater = true
        pcall(function() rp.RespectCanCollide = true end) -- süs / geçilebilir parçalar (CanCollide=false) engel sayılmaz
        local ignore = charsList()
        for _ = 1, 6 do
            rp.FilterDescendantsInstances = ignore
            local hit = workspace:Raycast(origin, dir, rp)
            if not hit then return true end
            -- Hedefin kendi gövdesine/yakınına denk gelen çarpma engel sayılmaz
            if (hit.Position - origin).Magnitude >= dist - 3 then return true end
            local inst = hit.Instance
            -- Aksesuar / kıyafet / geçilebilir parçalar engel değildir: listeye ekleyip ışını tekrar at
            if inst and (inst.CanCollide == false or inst:FindFirstAncestorOfClass("Accessory") ~= nil) then
                ignore[#ignore + 1] = inst
            else
                return false
            end
        end
        return false
    end

    -- Hedefin gövde / baş / ayak noktalarından herhangi biri görünüyorsa "görüyor" say
    function SFX.targetVisible(originPos, part, aim)
        if hasLineOfSight(originPos, aim) then return true end
        local ch = part.Parent
        local head = ch and ch:FindFirstChild("Head")
        if head and head:IsA("BasePart") and hasLineOfSight(originPos, head.Position) then return true end
        if hasLineOfSight(originPos, aim + Vector3.new(0, 1.8, 0)) then return true end
        if hasLineOfSight(originPos, aim - Vector3.new(0, 1.8, 0)) then return true end
        return false
    end

    -- Kamera/fare kullanmadan ateş eder; hedef ölene kadar her seferinde GÜNCEL konuma
    -- yeniden nişan alıp tekrar vurur (mermi hedefi takip eder).
    local shotToken = 0
    SFX.shootLeftOn = false   -- Sol tıkla keskin vuruş anahtarı (yerel değişken sınırına takılmamak için tabloda)
    local lastLosWarn = 0
    local function shootTarget()
        if os.clock() - lastShot < 0.35 then return end
        -- Silah çantandaysa da çalışır: ateşten önce silah otomatik ele alınır (fireGunAt içinde).
        -- Silah hiç yoksa (Sheriff / kahraman değilsin) uyarı verilir.
        local heldGun = findGun()
        if not (heldGun and LocalPlayer.Character) then
            notify("Sheriff olmalısın!", "Keskin vuruş için silah sende olmalı.", 3)
            return
        end
        -- Silahı HEMEN ele almaya başla (hedef seçimi / görüş kontrolüyle aynı anda ilerlesin)
        do
            local hum0 = myHum()
            if hum0 and heldGun.Parent ~= LocalPlayer.Character then
                pcall(function() hum0:EquipTool(heldGun) end)
            end
        end
        local part, hum = pickTarget()
        if not part then
            shootWarn("Hedef (katil) bulunamadı. Turun başladığından ve katilin hayatta olduğundan emin ol.")
            return
        end
        -- "Duvar Arkası Vuruş" (PREMİUM) kapalıyken: gerçek görüş hattı şart, yoksa ateş etme.
        -- Açıkken (ve premium aktifken): aşağıdaki fireGunAt zaten doğrudan konuma ateş eder,
        -- görüş hattı kontrol edilmez (duvarın arkasından da katile gitmeyi dener).
        if not (wallOn and Settings.PremiumActive) then
            local originPos = (myHRP() and myHRP().Position) or part.Position
            if not SFX.targetVisible(originPos, part, aimPoint(part, hum)) then
                if os.clock() - lastLosWarn > 2.5 then
                    lastLosWarn = os.clock()
                    pcall(notifyTop, "🧱 Hedef duvar arkasında, görmeden vuramazsın. (Premium: Duvar Arkası Vuruş'u aç)", 3)
                end
                return
            end
        end
        lastShot = os.clock()
        shotToken = shotToken + 1
        local my = shotToken
        task.spawn(function()
            -- Bu tuş basışının tekrar denemeleri (en fazla 5 atış) tek bir ateş sesi çıkarsın
            SFX.inBurst, SFX.burstPlayed, SFX.burstFx = true, false, false
            pcall(function()
                local fails = 0
                for _ = 1, 6 do
                    if not alive or my ~= shotToken then return end
                    if not (part.Parent and hum.Parent and hum.Health > 0) then return end -- hedef öldü
                    local _, fired = pcall(fireGunAt, function() return aimPoint(part, hum) end)
                    if not fired then
                        -- Silah o an hazır değilse (ele alınıyor / yeniden doğuyor) kısa bekleyip 2 kez daha dene
                        fails = fails + 1
                        if fails >= 3 then return end
                        task.wait(0.25)
                        continue
                    end
                    -- Varsayılan: BİR basış = BİR atış (kendi kendine tekrar ateş etmez).
                    -- "Iskalarsa Otomatik Tekrar Vur" açıksa sonucu bekleyip gerekirse yeniden vurur.
                    if not SFX.retryOn then return end
                    local waitT = 0.6 + getPingSeconds()
                    local t0 = os.clock()
                    while os.clock() - t0 < waitT do
                        if not alive or my ~= shotToken then return end
                        task.wait(0.05)
                    end
                end
            end)
            if my == shotToken then SFX.inBurst = false end
        end)
    end

    ---------------------------------------------------------
    -- DUVAR ARKASI VURUŞ (PREMİUM)
    -- Silahla normal ateş edince (nereye baktığın önemli değil) atışın hedef noktası katilin
    -- gideceği konumla değiştirilir; mermi duvarlardan / engellerden geçip katile gider.
    ---------------------------------------------------------
    -- Tıklayınca: gerçek atış hook ile katile yönlendirildiyse EKSTRA atış yapılmaz (çift atış yok).
    -- Hook yoksa ya da gerçek atış yönlendirilemediyse (0.18 sn içinde) script atışı yapılır.
    function SFX.clickShoot()
        if not hookReady then task.defer(shootTarget) return end
        local t = os.clock()
        task.delay(0.18, function()
            if (SFX.lastRedirect or 0) < t then shootTarget() end
        end)
    end

    wallRedirect = function(key, args)
        local premiumWall = wallOn and Settings.PremiumActive
        if not (premiumWall or SFX.shootLeftOn) then return nil end
        local m = findRole("Murderer", true)
        local ch = m and m.Character
        local hum = ch and ch:FindFirstChildOfClass("Humanoid")
        local part = ch and targetPartOf(ch)
        if not (part and hum and hum.Health > 0) then return nil end
        local handle
        local gun = findGun()
        if gun then handle = gun:FindFirstChild("Handle") end
        local origin = (handle and handle:IsA("BasePart") and handle.Position) or (myHRP() and myHRP().Position)
        local aim = aimPoint(part, hum)
        -- Duvar Arkası (premium) kapalıysa sadece görüş hattı varken yönlendir
        if not premiumWall then
            local op = (myHRP() and myHRP().Position) or part.Position
            if not SFX.targetVisible(op, part, aim) then return nil end
        end
        return withPos(args, aim, origin)
    end

    -- Silah elindeyken tıklayınca katile DOĞRUDAN kendi ateşimizi de gönder.
    -- Önceden bu sadece executor __namecall hook'unu desteklemiyorsa çalışıyordu; o zaman
    -- hook varsa özellik SADECE gerçek oyun silahının gerçekten ateş etmesine (yani oyunun
    -- kendi görüş hattı / menzil kısıtlarına) bağlı kalıyordu, bu da "duvar arkasında, nerede
    -- olursam olayım" isteğini bozuyordu. Artık hook olsun olmasın HER ZAMAN da çalışır:
    -- shootTarget() kameraya/nişana hiç bakmadan katilin güncel konumunu hesaplayıp direkt
    -- ateş eder, böylece haritanın herhangi bir yerinde, göz teması olmadan da vurabilirsin.
    bind(UserInputService.InputBegan, function(input, gpe)
        if gpe or not wallOn or not Settings.PremiumActive then return end
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.Touch then return end
        local gun = findGun()
        if gun and gun.Parent == LocalPlayer.Character then
            SFX.clickShoot()
        end
    end)

    ---------------------------------------------------------
    -- OYUNCU ÖLDÜRME (katil: bıçak • polis/kahraman: silah)
    ---------------------------------------------------------
    local mm2Target = nil
    local killBusy = false

    local function currentTarget()
        if mm2Target and mm2Target.Parent then return mm2Target end
        -- MM2 sekmesinde seçim yoksa Troll sekmesindeki seçili oyuncu kullanılır
        local g = Settings.GetSelectedTarget and Settings.GetSelectedTarget()
        if g and g.Parent then return g end
        return nil
    end

    local function findKnife()
        local ch = LocalPlayer.Character
        local k = ch and ch:FindFirstChild("Knife")
        if k and k:IsA("Tool") then return k end
        local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
        k = bp and bp:FindFirstChild("Knife")
        if k and k:IsA("Tool") then return k end
        return nil
    end

    local function equipTool(tool)
        local ch, hum = LocalPlayer.Character, myHum()
        if hum and tool.Parent ~= ch then
            pcall(function() hum:EquipTool(tool) end)
            local t0 = os.clock()
            while tool.Parent ~= ch and os.clock() - t0 < 0.6 do task.wait() end
        end
        return tool.Parent == ch
    end

    local function targetAlive(plr)
        return plr ~= nil and plr.Parent ~= nil and isAlive(plr)
    end

    -- Hedefin hemen arkasına geçip bıçakla vurur; ölene kadar en fazla 4 kez dener
    local function stabPlayer(plr, knife)
        local tries = 0
        while alive and targetAlive(plr) and tries < 4 do
            tries = tries + 1
            local hrp = myHRP()
            local th = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
            if not hrp or not th then break end
            hrp.CFrame = CFrame.lookAt((th.CFrame * CFrame.new(0, 0, 2.2)).Position, th.Position)
            hrp.AssemblyLinearVelocity = Vector3.zero
            local stab = knife:FindFirstChild("Stab")
            if stab then pcall(function() callRemote(stab, "Slash") end) end
            pcall(function() knife:Activate() end)
            pcall(function()
                local handle = knife:FindFirstChild("Handle")
                if firetouchinterest and handle then
                    firetouchinterest(th, handle, 0)
                    firetouchinterest(th, handle, 1)
                end
            end)
            task.wait(0.22)
        end
        return not targetAlive(plr)
    end

    local function killPlayer(plr)
        if killBusy or not plr or plr == LocalPlayer or not targetAlive(plr) then return end
        local hrp, hum = myHRP(), myHum()
        if not hrp or not hum or hum.Health <= 0 then return end
        killBusy = true
        task.spawn(function()
            pcall(function()
                local origin = hrp.CFrame
                local knife = findKnife()
                if knife and equipTool(knife) then
                    stabPlayer(plr, knife)
                    local h2 = myHRP()
                    if h2 then h2.CFrame = origin end -- işini bitirince eski yerine dön
                elseif findGun() then
                    local th = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
                    if th then
                        fireGunAt(th.Position + th.AssemblyLinearVelocity * getPingSeconds())
                    end
                end
            end)
            killBusy = false
        end)
    end

    local function killAll()
        if killBusy then return end
        local hrp, hum = myHRP(), myHum()
        if not hrp or not hum or hum.Health <= 0 then return end
        local knife = findKnife()
        if not knife then return end -- Kill All yalnızca katilken (bıçak varken) çalışır
        killBusy = true
        task.spawn(function()
            pcall(function()
                local origin = hrp.CFrame
                if equipTool(knife) then
                    local list = {}
                    for _, p in ipairs(Players:GetPlayers()) do
                        if p ~= LocalPlayer and isAlive(p) then
                            list[#list + 1] = {
                                p = p,
                                d = (p.Character.HumanoidRootPart.Position - hrp.Position).Magnitude,
                            }
                        end
                    end
                    table.sort(list, function(a, b) return a.d < b.d end) -- en yakından başla
                    for _, e in ipairs(list) do
                        local h = myHum()
                        if not alive or not h or h.Health <= 0 then break end
                        if targetAlive(e.p) then stabPlayer(e.p, knife) end
                    end
                end
                local h2 = myHRP()
                if h2 then h2.CFrame = origin end
            end)
            killBusy = false
        end)
    end

    -- Fling artık ortak modülde (Özellikler sekmesi ile paylaşılır)
    local flingTarget = Settings.FlingKit.fling

    -- Troll sekmesindeki 14. özellik de aynı fırlatmayı kullanır (yalnızca MM2'de var)
    Settings.MM2FlingPlayer = function(plr) flingTarget(plr) end

    ---------------------------------------------------------
    -- DÜŞEN SİLAHA IŞINLANMA
    ---------------------------------------------------------
    -- Düşen silah: oyun "GunDrop" adlı nesneyi (veya sahipsiz "Gun" aletini) workspace'e koyar.
    -- Doğrudan çocuk, derin arama ve DescendantAdded dinleyicisi ile kesin tespit edilir.
    local gunDropCache, gunScanStamp = nil, 0

    local function isDroppedGun(d)
        if d.Name == "GunDrop" then return true end
        if d.Name == "Gun" and d:IsA("Tool") then
            local par = d.Parent
            if par and not par:IsA("Backpack") and not Players:GetPlayerFromCharacter(par) then
                return true
            end
        end
        return false
    end

    bind(workspace.DescendantAdded, function(d)
        if d.Name == "GunDrop" or d.Name == "Gun" then
            if isDroppedGun(d) then gunDropCache = d end
        end
    end)

    local function gunDropInfo()
        local gd = gunDropCache
        if gd and (not gd.Parent or not gd:IsDescendantOf(workspace) or not isDroppedGun(gd)) then
            gd = nil
        end
        if not gd then
            gd = workspace:FindFirstChild("GunDrop")
            if not gd and os.clock() - gunScanStamp > 1 then
                gunScanStamp = os.clock()
                gd = workspace:FindFirstChild("GunDrop", true)
            end
        end
        gunDropCache = gd
        if not gd then return nil end
        local part = gd:IsA("BasePart") and gd or gd:FindFirstChildWhichIsA("BasePart", true)
        if not part then return nil end
        return gd, part
    end

    local function hasGun()
        local ch = LocalPlayer.Character
        if ch and ch:FindFirstChild("Gun") then return true end
        local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
        return bp ~= nil and bp:FindFirstChild("Gun") ~= nil
    end

    -- Silaha ışınlanır; silah envantere girer girmez veya karakter
    -- silaha temas eder etmez başlangıç konumuna döner.
    local grabbing = false
    local lastGunDiag = 0
    local function gunDiag(msg)
        if os.clock() - lastGunDiag < 4 then return end
        lastGunDiag = os.clock()
        pcall(notifyTop, "🔫 " .. msg, 2.5)
    end

    local function gunHeldByAnotherPlayer()
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                local character = player.Character
                if character and character:FindFirstChild("Gun") then
                    return player
                end
                local backpack = player:FindFirstChildOfClass("Backpack")
                if backpack and backpack:FindFirstChild("Gun") then
                    return player
                end
            end
        end
        return nil
    end

    local function gotoGun(auto)
        if grabbing then return false, false end
        local gd, part = gunDropInfo()
        if not gd then
            if not auto then
                local holder = gunHeldByAnotherPlayer()
                if holder then
                    notify("Silah yerde değil!", holder.DisplayName .. " taşıyor.", 3)
                else
                    notify("Yerde silah yok!", "Silahın düşmesini bekle.", 3)
                end
            end
            return false, false
        end
        local role, dead = myRole()
        if dead or role == "Murderer" then
            if auto then gunDiag("Katilsin, silah alamazsin.") end
            return false, false
        end
        local hrp = myHRP()
        if not hrp then return false, false end
        if auto then
            local m = findRole("Murderer", true)
            local mh = m and m.Character and m.Character:FindFirstChild("HumanoidRootPart")
            if mh and (mh.Position - part.Position).Magnitude < 14 then
                gunDiag("Katil silahin yaninda, bekleniyor...")
                return false, false
            end
        end

        grabbing = true
        local origin = hrp.CFrame
        local got, touched = hasGun(), false
        local finished = false
        local connections = {}

        local function disconnectAll()
            for _, c in ipairs(connections) do
                pcall(function() c:Disconnect() end)
            end
            table.clear(connections)
        end

        local function returnNow()
            if finished then return end
            finished = true
            disconnectAll()

            local h = myHRP()
            if h then
                pcall(function()
                    h.CFrame = origin
                    h.AssemblyLinearVelocity = Vector3.zero
                    h.AssemblyAngularVelocity = Vector3.zero
                end)
            end
            grabbing = false
        end

        local function checkInventory()
            if hasGun() then
                got = true
                returnNow()
            end
        end

        -- Silah Backpack'e veya Character'a eklendiği an beklemeden dön.
        local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
        if backpack then
            connections[#connections + 1] = backpack.ChildAdded:Connect(function(child)
                if child.Name == "Gun" then
                    got = true
                    returnNow()
                end
            end)
        end

        local character = LocalPlayer.Character
        if character then
            connections[#connections + 1] = character.ChildAdded:Connect(function(child)
                if child.Name == "Gun" then
                    got = true
                    returnNow()
                end
            end)
        end

        -- Karakterin herhangi bir parçası düşen silaha değdiğinde anında dön.
        connections[#connections + 1] = part.Touched:Connect(function(hit)
            local ch = LocalPlayer.Character
            if ch and hit and hit:IsDescendantOf(ch) then
                touched = true
                returnNow()
            end
        end)

        local t0 = os.clock()
        while alive and not finished and os.clock() - t0 < 1.6 do
            checkInventory()
            if finished then break end

            local currentDrop, currentPart = gunDropInfo()
            if not currentDrop or not currentPart then
                -- Silah yerden kalktıysa envanteri kontrol edip geri dön.
                checkInventory()
                if not finished then returnNow() end
                break
            end

            local h = myHRP()
            if not h then
                returnNow()
                break
            end

            tpTo(currentPart.Position + Vector3.new(0, 1.5, 0))

            pcall(function()
                if firetouchinterest then
                    local ch = LocalPlayer.Character
                    for _, nm in ipairs({"HumanoidRootPart", "RightFoot", "LeftFoot", "RightLowerLeg", "LeftLowerLeg"}) do
                        local bp = ch and ch:FindFirstChild(nm)
                        if bp then
                            firetouchinterest(bp, currentPart, 0)
                            firetouchinterest(bp, currentPart, 1)
                        end
                    end
                end
            end)

            -- Sadece bir fizik karesi beklenir; envanter/temas olayları
            -- gelirse döngü Heartbeat'i beklemeden sonlandırılır.
            if not finished then
                RunService.Heartbeat:Wait()
            end
        end

        got = got or hasGun()
        if not finished then returnNow() end
        return got or touched, true
    end

    local lastGunTry = 0
    local function autoGunStep()
        local gd = gunDropInfo()
        if not gd then
            gunAttempts, lastGunObj = 0, nil
            return
        end
        if gd ~= lastGunObj then
            lastGunObj = gd
            gunAttempts = 0
        end
        if gunAttempts >= 4 or hasGun() or grabbing then return end
        if os.clock() - lastGunTry < 0.8 then return end
        lastGunTry = os.clock()
        local _, attempted = gotoGun(true)
        if attempted then gunAttempts = gunAttempts + 1 end
    end

    ---------------------------------------------------------
    -- DÜŞEN SİLAH ESP (turuncu) + ÜSTTE BİLDİRİM
    ---------------------------------------------------------
    local GUN_COLOR = Color3.fromRGB(255, 140, 0)
    local gunEspOn, gunNotifyOn = false, true -- Düşen Silah ESP, Rol ESP'ye bağlıdır (ayrı anahtarı yok)
    local gunHL, gunTag, gunTagLabel, lastDropSeen, topBanner = nil, nil, nil, nil, nil
    local gunBox, gunFolder = nil, nil

    -- Kayıtlı anahtar durumu varsa onu, yoksa varsayılanı döndürür (arayüz ile değişken senkron kalsın)
    local function savedOr(text, default)
        local v = Settings.ToggleStates[text]
        if v == nil then return default end
        return v == true
    end

    local function clearGunEsp()
        if gunHL then pcall(function() gunHL:Destroy() end) gunHL = nil end
        if gunTag then pcall(function() gunTag:Destroy() end) gunTag, gunTagLabel = nil, nil end
        pcall(function() RunService:UnbindFromRenderStep("EZRAGOX_GunTagPos") end)
        if SFX.gunTagLayer then pcall(function() SFX.gunTagLayer:Destroy() end) SFX.gunTagLayer = nil end
        SFX.gunTagPart = nil
    end

    local function showTopBanner(title, subtitle)
        if suppressNotify then return true end
        return pcall(function()
            if topBanner then topBanner:Destroy() end
            -- Panelin imza görünümü: diyagonal kırmızı/kömür degrade + nabız gibi parlayan kenarlık
            local f = new("CanvasGroup", {
                AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, -70),
                Size = UDim2.new(0, 380, 0, 56), BackgroundTransparency = 1,
                BorderSizePixel = 0, ZIndex = 400,
            }, ScreenGui)
            topBanner = f
            corner(f, 20)
            local bannerBg = new("Frame", {
                Name = "WeaponBannerBackground",
                Size = UDim2.fromScale(1, 1),
                BackgroundColor3 = Color3.fromRGB(23, 11, 16),
                BorderSizePixel = 0,
                ZIndex = 400,
            }, f)
            corner(bannerBg, 20)
            new("UIGradient", {
                Rotation = 0,
                Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Color3.fromRGB(43, 13, 21)),
                    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(23, 11, 16)),
                    ColorSequenceKeypoint.new(1, Color3.fromRGB(13, 9, 13)),
                }),
                Transparency = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, 0.05),
                    NumberSequenceKeypoint.new(1, 0.3),
                }),
            }, bannerBg)
            -- Bildirim rengi: panelin kırmızı-siyah teması (silah ESP'nin turuncusundan bağımsız)
            local BANNER_COLOR = Color3.fromRGB(255, 45, 65)
            local glowStroke = stroke(f, 2, BANNER_COLOR, 0.15)
            local banBar = new("Frame", {
                Size = UDim2.new(0, 4, 1, 0), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 401,
            }, f)
            local banBarGrad = new("UIGradient", {Rotation = 90}, banBar)
            banBarGrad.Color = notifFlowSeq(math.random() * 5, 0.5)
            new("TextLabel", {
                Position = UDim2.new(0, 14, 0, 6), Size = UDim2.new(1, -14, 0, 24), BackgroundTransparency = 1,
                Text = title, Font = Enum.Font.GothamBlack, TextSize = 17, TextColor3 = Color3.fromRGB(255, 255, 255),
                TextTransparency = 0, TextStrokeTransparency = 1, RichText = false, ZIndex = 402,
            }, f)
            new("TextLabel", {
                Position = UDim2.new(0, 14, 0, 29), Size = UDim2.new(1, -14, 0, 20), BackgroundTransparency = 1,
                Text = subtitle, Font = Enum.Font.GothamMedium, TextSize = 12,
                TextColor3 = Color3.fromRGB(255, 255, 255),
                TextTransparency = 0, TextStrokeTransparency = 1, RichText = false, ZIndex = 402,
            }, f)
            local scale = new("UIScale", {Scale = 0.9}, f)

            -- Performans: her karede Lua calistirmak yerine motor tarafinda dongulu tween kullanilir
            glowStroke.Transparency = 0.0
            TweenService:Create(glowStroke, TweenInfo.new(1.0, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {Transparency = 0.33}):Play()

            tween(f, 0.4, {Position = UDim2.new(0.5, 0, 0, 96)}, Enum.EasingStyle.Back)
            tween(scale, 0.35, {Scale = 1}, Enum.EasingStyle.Back)
            pcall(function() playSound(1.5, 0.5) end)
            task.delay(4.5, function()
                if topBanner == f then
                    tween(f, 0.35, {Position = UDim2.new(0.5, 0, 0, -56)}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
                    tween(scale, 0.3, {Scale = 0.9})
                    task.delay(0.4, function()
                        pcall(function() f:Destroy() end)
                        if topBanner == f then topBanner = nil end
                    end)
                end
            end)
        end)
    end

    local function getGunFolder()
        if gunFolder and gunFolder.Parent then return gunFolder end
        gunFolder = Instance.new("Folder")
        gunFolder.Name = "EZRAGOX_GunESP"
        gunFolder.Parent = ScreenGui.Parent or CoreGui
        return gunFolder
    end

    -- Düşen silah etiketi: BillboardGui yerine ScreenGui katmanında çizilir.
    -- Böylece "Ekran Genişletme" (kamerayı dikeyde sıkıştırma) etiketi bozmaz / kaydırmaz;
    -- yazı her zaman normal boyutta ve silahın üstünde görünür.
    local function makeGunTag(part)
        local layer = SFX.gunTagLayer
        if not (layer and layer.Parent) then
            layer = Instance.new("ScreenGui")
            layer.Name = "EZRAGOX_GunTagLayer"
            layer.ResetOnSpawn = false
            layer.IgnoreGuiInset = true
            layer.DisplayOrder = 9999
            layer.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
            layer.Parent = ScreenGui.Parent or CoreGui
            SFX.gunTagLayer = layer
        end
        SFX.gunTagPart = part
        local fr = Instance.new("Frame")
        fr.Name = "EZRAGOX_MM2_GUNTAG"
        fr.AnchorPoint = Vector2.new(0.5, 1)
        fr.Size = UDim2.fromOffset(230, 34)
        fr.BackgroundColor3 = Color3.fromRGB(14, 10, 8)
        fr.BackgroundTransparency = 0.2
        fr.BorderSizePixel = 0
        fr.Visible = false
        fr.Parent = layer
        local fc = Instance.new("UICorner")
        fc.CornerRadius = UDim.new(1, 0)
        fc.Parent = fr
        local fs = Instance.new("UIStroke")
        fs.Thickness = 2
        fs.Color = GUN_COLOR
        fs.Parent = fr
        local lab = Instance.new("TextLabel")
        lab.Size = UDim2.new(1, 0, 1, 0)
        lab.BackgroundTransparency = 1
        lab.Font = Enum.Font.GothamBold
        lab.TextSize = 15
        lab.TextColor3 = GUN_COLOR
        lab.Text = "🔫 Düşen Silah"
        lab.Parent = fr
        -- Konum her karede, ekran genişletme kamerayı ayarladıktan SONRA hesaplanır
        pcall(function() RunService:UnbindFromRenderStep("EZRAGOX_GunTagPos") end)
        RunService:BindToRenderStep("EZRAGOX_GunTagPos", Enum.RenderPriority.Camera.Value + 2, function()
            local f, pt = gunTag, SFX.gunTagPart
            if not (f and f.Parent and pt and pt.Parent) then
                if f then f.Visible = false end
                return
            end
            local cam = workspace.CurrentCamera
            if not cam then return end
            local pnt, vis = cam:WorldToViewportPoint(pt.Position + Vector3.new(0, 3, 0))
            local on = vis and pnt.Z > 0
            f.Visible = on
            if on then f.Position = UDim2.fromOffset(pnt.X, pnt.Y) end
        end)
        return fr, lab
    end

    local function gunWatchStep()
        local gd, part = gunDropInfo()
        if not gd then
            lastDropSeen = nil
            clearGunEsp()
            return
        end
        local hrp = myHRP()
        local dist = hrp and math.floor((part.Position - hrp.Position).Magnitude) or 0
        if gd ~= lastDropSeen then
            lastDropSeen = gd
            if gunNotifyOn then
                local ok = showTopBanner("🔫  SİLAH DÜŞTÜ!", "Mesafe: " .. dist .. " m  •  Işınlanma tuşu: " .. Settings.MM2GunKey.Name)
                if not ok then pcall(notifyTop, "🔫 SİLAH DÜŞTÜ!  " .. dist .. " m", 4) end
            end
        end
        if gunEspOn then
            if not gunHL or not gunHL.Parent or gunHL.Adornee ~= gd then
                if gunHL then pcall(function() gunHL:Destroy() end) end
                gunHL = nil
                pcall(function()
                    gunHL = makeHighlight(gd, getGunFolder())
                    gunHL.FillColor = GUN_COLOR
                    gunHL.OutlineColor = GUN_COLOR
                    gunHL.FillTransparency = 0.1
                    gunHL.OutlineTransparency = 0
                end)
            end
            if not gunTag or not gunTag.Parent or SFX.gunTagPart ~= part then
                if gunTag then pcall(function() gunTag:Destroy() end) end
                gunTag, gunTagLabel = makeGunTag(part)
            end
            if gunTagLabel then gunTagLabel.Text = "🔫 Düşen Silah • " .. dist .. " m" end
        else
            clearGunEsp()
        end
    end

    ---------------------------------------------------------
    -- OTOMATİK KAÇIŞ (katil yaklaşınca güvenli noktaya)
    ---------------------------------------------------------
    -- Adaylar yalnızca harita İÇİNDEKİ noktalardır (doğuş noktaları, coinler, diğer oyuncular).
    -- Hepsi zemin + boş alan kontrolünden geçer: duvar içine / harita dışına ışınlanmaz.
    local function pickSafeSpot(murdererPos, myPos)
        local candidates = {}
        local map = findMap()
        if map then
            local sp = map:FindFirstChild("Spawns")
            if sp then
                for _, s in ipairs(sp:GetChildren()) do
                    if s:IsA("BasePart") then candidates[#candidates + 1] = s.Position end
                end
            end
            local cc = map:FindFirstChild("CoinContainer")
            if cc then
                for _, c in ipairs(cc:GetChildren()) do
                    if c:IsA("BasePart") then candidates[#candidates + 1] = c.Position end
                end
            end
        end
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and isAlive(p) then
                candidates[#candidates + 1] = p.Character.HumanoidRootPart.Position
            end
        end
        local minFromKiller = math.max(escapeDist * 1.8, 45)
        local best, bestScore
        for _, pos in ipairs(candidates) do
            local dKiller = (pos - murdererPos).Magnitude
            local dMe = (pos - myPos).Magnitude
            if dKiller >= minFromKiller and dMe >= 12 then
                local ground = groundAt(pos)
                if ground and spaceFree(ground) then
                    -- Biraz uzağa: güvenli olanlar arasında bana en yakın nokta
                    if not best or dMe < bestScore then
                        best, bestScore = ground, dMe
                    end
                end
            end
        end
        return best
    end

    local function escapeStep()
        if os.clock() - lastEscape < ESCAPE_COOLDOWN then return end
        local hrp, hum = myHRP(), myHum()
        if not hrp or not hum or hum.Health <= 0 then return end
        local role, dead = myRole()
        if dead or role == "Murderer" then return end
        local m = findRole("Murderer", true)
        local mh = m and m.Character and m.Character:FindFirstChild("HumanoidRootPart")
        if not mh then return end
        if (mh.Position - hrp.Position).Magnitude > escapeDist then return end
        local spot = pickSafeSpot(mh.Position, hrp.Position)
        if spot then
            lastEscape = os.clock()
            tpTo(spot + Vector3.new(0, 3.2, 0))
        end
    end

    ---------------------------------------------------------
    -- OTO COİN FARM (havada noclip süzülerek, yavaşça)
    ---------------------------------------------------------
    local function setNoclip(on)
        if on then
            if noclipConn then return end
            noclipConn = RunService.Stepped:Connect(function()
                local ch = LocalPlayer.Character
                if not ch then return end
                for _, d in ipairs(Settings.CharParts(ch)) do
                    if d.CanCollide then d.CanCollide = false end
                end
            end)
        elseif noclipConn then
            noclipConn:Disconnect()
            noclipConn = nil
        end
    end

    local function releaseFarm()
        -- Yerin altındaysak önce yüzeye çıkar ve dik duruşa dön (yoksa boşluğa düşer)
        if underground then
            underground = false
            local hrp0 = myHRP()
            if hrp0 then
                local up = surfacePos or farmStart
                local pos = up and (up + Vector3.new(0, 4, 0)) or (hrp0.Position + Vector3.new(0, UNDER_DEPTH + 4, 0))
                hrp0.CFrame = CFrame.new(pos)
                hrp0.AssemblyLinearVelocity = Vector3.zero
                hrp0.AssemblyAngularVelocity = Vector3.zero
            end
        end
        setNoclip(false)
        local hum = myHum()
        if hum and hum.PlatformStand then
            hum.PlatformStand = false
            pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)
        end
    end

    local function flyTowards(target, speed, timeout, stopDist)
        local t0 = os.clock()
        local cur = nil -- kendi konumumuzu biz tutarız: yerçekimi her karede bizi azıcık aşağı çekmesin
        while alive and farmOn and os.clock() - t0 < timeout do
            local dt = RunService.Heartbeat:Wait()
            local hrp, hum = myHRP(), myHum()
            if not hrp or not hum or hum.Health <= 0 then return false end
            hum.PlatformStand = true
            if not cur or (hrp.Position - cur).Magnitude > 25 then cur = hrp.Position end
            local d = target - cur
            local dist = d.Magnitude
            if dist <= (stopDist or 0.7) then
                hrp.CFrame = CFrame.new(cur) * LIE_ANGLE
                hrp.AssemblyLinearVelocity = Vector3.zero
                return true
            end
            local step = math.min(dist, speed * dt)
            cur = cur + d.Unit * step
            hrp.CFrame = CFrame.new(cur) * LIE_ANGLE
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end
        return false
    end

    -- Yerin altında yatay duruşta sabit bekle (düşmeden / görünmeden)
    local function holdUnder()
        local hrp, hum = myHRP(), myHum()
        if not hrp or not hum or hum.Health <= 0 then return end
        setNoclip(true)
        hum.PlatformStand = true
        hrp.CFrame = CFrame.new(hrp.Position) * LIE_ANGLE
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
    end

    local function listCoins(map)
        local out = {}
        local cc = map and map:FindFirstChild("CoinContainer")
        if not cc then return out end
        for _, c in ipairs(cc:GetChildren()) do
            if c:IsA("BasePart") and not visited[c] and (coinRetryAt[c] or 0) <= os.clock() and string.find(c.Name, "Coin") then
                out[#out + 1] = c
            end
        end
        return out
    end

    local function goBase()
        local lobby = getLobbyPos()
        if lobby then
            tpTo(lobby)
        elseif farmStart then
            tpTo(farmStart)
        end
    end

    local function farmStep()
        local hum, hrp = myHum(), myHRP()
        if not hum or not hrp or hum.Health <= 0 then
            underground, surfacePos = false, nil -- ölüyüz: eski haritaya geri ışınlama yapma
            releaseFarm()
            task.wait(0.5)
            return
        end

        -- Olduğun yerde sabit dur (yerçekimi seni aşağı çekmesin): her karede konumu geri yazar
        local function holdFor(t)
            local h0 = myHRP()
            if not h0 then task.wait(t) return end
            local cf0 = h0.CFrame
            local t0 = os.clock()
            while alive and farmOn and os.clock() - t0 < t do
                RunService.Heartbeat:Wait()
                local h1 = myHRP()
                if not h1 then return end
                h1.CFrame = cf0
                h1.AssemblyLinearVelocity = Vector3.zero
                h1.AssemblyAngularVelocity = Vector3.zero
            end
        end

        local _, dead = myRole()
        local map = findMap()
        if not map or dead then
            -- Raunt yok ya da ölüyüz: bekle (eski haritaya geri ışınlama YOK)
            underground, surfacePos = false, nil
            releaseFarm()
            if farmMap ~= nil then
                farmMap, visited, visitedCount, bagNow = nil, {}, 0, 0
            end
            farmDone, noCoinTimer = false, nil
            Settings.FarmEntered, Settings.FarmLastPos = false, nil
            task.wait(0.6)
            return
        end
        if map ~= farmMap then
            farmMap, visited, visitedCount, bagNow = map, {}, 0, 0
            farmDone, noCoinTimer = false, nil
            Settings.FarmEntered, Settings.FarmLastPos = false, nil
        end
        if farmDone then
            releaseFarm()
            task.wait(0.6)
            return
        end

        -- Çanta doldu mu?
        local full
        if bagEventSeen then full = bagNow >= bagMax else full = visitedCount >= bagMax end
        if full then
            releaseFarm()
            goBase()
            farmDone = true
            return
        end

        local coins = listCoins(map)
        local me = hrp.Position

        -- En yakın coin
        local best, bd
        for _, c in ipairs(coins) do
            local d = (c.Position - me).Magnitude
            if not bd or d < bd then best, bd = c, d end
        end

        -- TUR BİTTİ / LOBİYE DÖNÜLDÜ: farm sırasında oyun bizi aniden uzağa ışınladıysa ve
        -- yakında coin yoksa farm bu tur için biter; yeni tur (yeni harita) başlayınca devam eder.
        local lp = Settings.FarmLastPos
        if Settings.FarmEntered and lp and (me - lp).Magnitude > 60 and (not bd or bd > 150) then
            underground, surfacePos = false, nil
            releaseFarm()
            farmDone, noCoinTimer = true, nil
            return
        end

        if #coins == 0 then
            -- Yeni coin çıkabilir; kısa süre sabit bekle, çıkmazsa baseye dön
            if underground then holdFor(0.4) else releaseFarm() task.wait(0.4) end
            noCoinTimer = noCoinTimer or os.clock()
            if os.clock() - noCoinTimer > 8 then
                releaseFarm()
                goBase()
                farmDone = true
            end
            return
        end
        noCoinTimer = nil

        -- Henüz haritaya girmediysek (lobideyiz, tur başlamadı) bekle; tur başlayınca devam et
        if not Settings.FarmEntered then
            if bd > 150 then
                task.wait(0.5)
                return
            end
            Settings.FarmEntered = true
        end

        local cp = best.Position

        -- Coine temas: tek geçişte birkaç vücut parçası
        local function touchBest()
            if not (best and best.Parent and firetouchinterest) then return end
            local ch = LocalPlayer.Character
            local contactParts = {"HumanoidRootPart", "RightFoot", "LeftFoot", "RightHand", "LeftHand"}
            for _, name in ipairs(contactParts) do
                local bodyPart = ch and ch:FindFirstChild(name)
                if bodyPart and bodyPart:IsA("BasePart") then
                    pcall(firetouchinterest, bodyPart, best, 0)
                    pcall(firetouchinterest, bodyPart, best, 1)
                end
            end
        end
        local function markResult(bagBefore, retryAfter)
            local collected = (not best.Parent) or (bagEventSeen and bagNow > bagBefore)
            if collected then
                visited[best] = true
                visitedCount = visitedCount + 1
            else
                coinRetryAt[best] = os.clock() + retryAfter
            end
        end

        ---------------------------------------------------------
        -- ZEMİNİN ALTINDAN SÜZÜLEREK FARM: karakter zeminin hemen altında (görünmez) ilerler,
        -- coine altından temas eder. Derinlik slider'dan ayarlanır; zemin her noktada ölçülür.
        ---------------------------------------------------------
        setNoclip(true)
        surfacePos = cp
        underground = true
        local spd = Settings.FarmTp and (Settings.FarmTpSpeed or 90) or farmSpeed
        local depth = Settings.FarmDepth or 2.5

        -- Zemin yüksekliği: aşağı doğru ışın (karakterler ve coinler hariç, çarpışmayan parçalar yok sayılır)
        local rayP = RaycastParams.new()
        rayP.FilterType = Enum.RaycastFilterType.Exclude
        local rayEx = charsList()
        local ccFolder = map:FindFirstChild("CoinContainer")
        if ccFolder then rayEx[#rayEx + 1] = ccFolder end
        rayP.FilterDescendantsInstances = rayEx
        rayP.RespectCanCollide = true
        local function groundBelow(from, dist)
            local r = workspace:Raycast(from, Vector3.new(0, -dist, 0), rayP)
            return r and r.Position.Y or nil
        end

        local gy = groundBelow(cp + Vector3.new(0, 0.5, 0), 60)
        local hideY = gy and (gy - depth) or (cp.Y - depth - 1.5)
        local goal = Vector3.new(cp.X, hideY, cp.Z)
        local startP = hrp.Position
        local flat = Vector3.new(goal.X - startP.X, 0, goal.Z - startP.Z).Magnitude
        local n = math.max(1, math.ceil(flat / 10))
        local reached = true
        for i = 1, n do
            if not farmOn then reached = false break end
            local pt = goal
            if i < n then
                -- Ara noktalarda da zemine göre aynı derinlikte kal (tepe/çukurda dışarı çıkma)
                local a = i / n
                local x = startP.X + (goal.X - startP.X) * a
                local z = startP.Z + (goal.Z - startP.Z) * a
                local lineY = startP.Y + (goal.Y - startP.Y) * a
                local g = groundBelow(Vector3.new(x, lineY + 5, z), 120)
                pt = Vector3.new(x, g and (g - depth) or lineY, z)
            end
            reached = flyTowards(pt, spd, 10, (i == n) and 0.8 or 2)
            if not reached then break end
        end

        if reached and farmOn then
            local bagBefore = bagNow
            touchBest()
            holdFor(0.05)
            if best.Parent and farmOn then
                -- Alınmadıysa yine zeminin altında kal ama coine biraz daha yaklaş
                local nearY = math.min(cp.Y - 0.6, (gy or (cp.Y - 3)) - 0.8)
                flyTowards(Vector3.new(cp.X, nearY, cp.Z), spd, 1.5, 0.4)
                touchBest()
                holdFor(0.07)
            end
            markResult(bagBefore, 0.8)
            -- Yukarı çıkma yok: sonraki en yakın coine yine zeminin altından ilerler.
        end
    end

    ---------------------------------------------------------
    -- TUŞ SEÇME SATIRI
    ---------------------------------------------------------
    local function mouseLabel(ut)
        return (ut == Enum.UserInputType.MouseButton3) and "🖱️  Orta Tık" or nil
    end

    local function keyRow(label, settingKey)
        local row, st = baseRow(MM2Page, "TextButton", 42)
        rowLabel(row, label)
        local initText = mouseLabel(Settings[settingKey .. "Mouse"]) or Settings[settingKey].Name
        local keyText = new("TextLabel", {
            AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.new(0, 150, 0, 26),
            BackgroundTransparency = 1, Text = initText, Font = Enum.Font.GothamBold, TextSize = 13,
            TextColor3 = Color3.fromRGB(255, 65, 75), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 4,
        }, row)
        hoverFx(row, st)
        bind(row.MouseButton1Click, function()
            playClickSound()
            listening = {key = settingKey, text = keyText}
            setText(keyText, "Bir tuşa/fare orta tuşuna basın...")
        end)
        return keyText
    end

    ---------------------------------------------------------
    -- MM2 TUR SÜRESİ • TAMAMEN OLAY TABANLI (sürekli döngü / tarama YOK)
    --  • Oyunun sayaç yazısı doğrudan yoldan bulunur (yerel arama, çok hızlı).
    --  • Yazı değişince (saniyede 1 kez) gösterge güncellenir; başka iş yapılmaz.
    --  • Sayaç bulunamazsa seyrek aralıklarla (0.5-30 sn) ve parça parça aranır.
    ---------------------------------------------------------
    local roundTimerSet = function() end
    local roundTimerDiag = function() end
    do
        local timerOn = false
        local tGui, tLbl, tBar, tDot
        local src, srcConn, srcAnc, pgConn, wsConn
        local lastText, prevSecs, maxSecs = nil, nil, 0
        local scanToken, finderRunning = 0, false

        -- Olası sayaç isimleri: oyun güncellenirse / adı farklıysa da bulunabilsin
        local NAME_CANDIDATES = {"Timer", "TimeLabel", "RoundTimer", "CountdownLabel", "Countdown", "TimeLeft", "RoundTime"}

        -- Basit zengin-metin etiketlerini temizler (<font color="...">2:05</font> gibi)
        local function stripTags(txt)
            if string.find(txt, "<", 1, true) then
                txt = string.gsub(txt, "<[^>]->", "")
            end
            return txt
        end

        -- Sayaç metni: "2:05", "2m 5s" (loose=true ise "Ends in 2:05" gibi önekleri de kabul eder)
        local function parseSecs(txt, loose)
            txt = stripTags(tostring(txt or ""))
            if #txt > 60 then return nil end
            local m, sec
            if loose then
                m, sec = string.match(txt, "(%d+)%s*:%s*(%d%d)")
                if not m then m, sec = string.match(txt, "(%d+)%s*m%s*(%d+)%s*s") end
            else
                m, sec = string.match(txt, "^%s*(%d+)%s*:%s*(%d%d)%s*$")
                if not m then m, sec = string.match(txt, "^%s*(%d+)%s*m%s*(%d+)%s*s?%s*$") end
            end
            if m and sec then
                local n = tonumber(m) * 60 + tonumber(sec)
                if n <= 3600 then return n end
            end
            return nil
        end

        local function isShown(o)
            local cur = o
            while cur and cur ~= game do
                if cur:IsA("GuiObject") and not cur.Visible then return false end
                if cur:IsA("ScreenGui") and not cur.Enabled then return false end
                if cur:IsA("SurfaceGui") and not cur.Enabled then return false end
                cur = cur.Parent
            end
            return true
        end

        local function render()
            if not (timerOn and tLbl) then return end
            local secs = (src and src.Parent) and parseSecs(src.Text, true) or nil
            local txt = secs and string.format("%d:%02d", math.floor(secs / 60), secs % 60) or "--:--"
            if txt == lastText then return end
            lastText = txt
            tLbl.Text = txt
            if secs then
                -- Yeni tur başlayınca (süre yukarı sıçrar) tam süreyi yeniden ölç
                if not prevSecs or secs > prevSecs + 3 or secs > maxSecs then maxSecs = secs end
                prevSecs = secs
                local urgent = secs <= 10
                local warnLvl = secs <= 30
                local col = urgent and Color3.fromRGB(255, 92, 92)
                    or (warnLvl and Color3.fromRGB(255, 176, 74) or Color3.fromRGB(120, 215, 255))
                tween(tLbl, 0.25, {TextColor3 = Color3.fromRGB(240, 243, 250)})
                tween(tDot, 0.25, {BackgroundColor3 = col})
                tween(tBar, 0.3, {Size = UDim2.new(math.clamp(secs / math.max(maxSecs, 1), 0, 1), 0, 1, 0), BackgroundColor3 = col})
            else
                prevSecs, maxSecs = nil, 0
                tween(tLbl, 0.25, {TextColor3 = Color3.fromRGB(135, 145, 170)})
                tween(tDot, 0.25, {BackgroundColor3 = Color3.fromRGB(100, 110, 135)})
                tween(tBar, 0.3, {Size = UDim2.new(0, 0, 1, 0)})
            end
        end

        local function detach()
            if srcConn then srcConn:Disconnect() srcConn = nil end
            if srcAnc then srcAnc:Disconnect() srcAnc = nil end
            src = nil
        end

        local startFinder
        local function attach(lbl)
            if src == lbl then return end
            detach()
            src = lbl
            srcConn = lbl:GetPropertyChangedSignal("Text"):Connect(render)
            srcAnc = lbl.AncestryChanged:Connect(function()
                if not lbl.Parent and src == lbl then
                    detach()
                    render()
                    if timerOn then startFinder() end
                end
            end)
            render()
        end

        -- Hızlı yerel arama (C++ tarafında): bilinen yollar + bilinen isimler (PlayerGui + workspace ekranları)
        local function quickFind()
            local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
            if pg then
                local main = pg:FindFirstChild("MainGUI")
                local g = main and main:FindFirstChild("Game")
                local t = g and g:FindFirstChild("Timer")
                if t and t:IsA("TextLabel") then return t end
                for _, nm in ipairs(NAME_CANDIDATES) do
                    t = pg:FindFirstChild(nm, true)
                    if t and t:IsA("TextLabel") then return t end
                end
            end
            -- Bazı oyunlarda sayaç, haritadaki fiziksel bir ekranda (SurfaceGui) gösterilir
            for _, nm in ipairs(NAME_CANDIDATES) do
                local t = workspace:FindFirstChild(nm, true)
                if t and t:IsA("TextLabel") then return t end
            end
            return nil
        end

        -- Yavaş yedek tarama: süre biçimli görünür yazıyı arar (parça parça, takılma yapmaz).
        -- root = PlayerGui veya workspace (fiziksel ekranlardaki yazılar için).
        local function deepScanIn(root, my)
            if not root then return nil end
            local list = root:GetDescendants()
            for i = 1, #list do
                if my ~= scanToken or not timerOn then return nil end
                local d = list[i]
                if d.ClassName == "TextLabel" and parseSecs(d.Text, true) and isShown(d) then
                    return d
                end
                if i % 300 == 0 then task.wait() end
            end
            return nil
        end
        local function deepScan(my)
            local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
            local f = deepScanIn(pg, my)
            if f then return f end
            return deepScanIn(workspace, my)
        end

        startFinder = function()
            if finderRunning or not timerOn then return end
            finderRunning = true
            local my = scanToken
            task.spawn(function()
                local delays = {0.5, 2, 4, 8, 15, 30}
                local i = 1
                while alive and timerOn and my == scanToken and not (src and src.Parent) do
                    local f = quickFind()
                    if not f and (i <= 2 or i % 3 == 0) then f = deepScan(my) end
                    if f and my == scanToken then attach(f) break end
                    task.wait(delays[math.min(i, #delays)])
                    i = i + 1
                end
                finderRunning = false
            end)
        end

        -- Modern, küçük ve göze batmayan tek-satır gösterge (hap biçimli, soft cam görünüm)
        local function buildGui()
            if tGui then return end
            tGui = new("Frame", {
                Name = "EZRAGOX_MM2_Timer",
                Size = UDim2.new(0, 108, 0, 34),
                Position = UDim2.new(0.5, -54, 0, 64),
                BackgroundColor3 = Color3.fromRGB(16, 18, 26),
                BackgroundTransparency = 0.18,
                BorderSizePixel = 0,
                Active = true,
                Visible = false,
                ClipsDescendants = true,
                ZIndex = 60,
            }, ScreenGui)
            pill(tGui)
            local st = stroke(tGui, 1, Color3.fromRGB(255, 255, 255), 0.82)

            tDot = new("Frame", {
                AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 11, 0.5, 0),
                Size = UDim2.new(0, 7, 0, 7), BackgroundColor3 = Color3.fromRGB(100, 110, 135), BorderSizePixel = 0, ZIndex = 61,
            }, tGui)
            pill(tDot)
            Pulsers[#Pulsers + 1] = {obj = tDot, prop = "BackgroundTransparency", base = 0, amp = 0.35, speed = 2.6}

            tLbl = new("TextLabel", {
                Position = UDim2.new(0, 24, 0, 0), Size = UDim2.new(1, -32, 1, 0), BackgroundTransparency = 1,
                Text = "--:--", Font = Enum.Font.GothamBold, TextSize = 15,
                TextColor3 = Color3.fromRGB(135, 145, 170), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 61,
            }, tGui)

            -- Alt kenarda ince, zarif ilerleme çizgisi (süre azaldıkça kısalır)
            local track = new("Frame", {
                Position = UDim2.new(0, 0, 1, -2), Size = UDim2.new(1, 0, 0, 2),
                BackgroundColor3 = Color3.fromRGB(255, 255, 255), BackgroundTransparency = 0.9, BorderSizePixel = 0, ZIndex = 61,
            }, tGui)
            tBar = new("Frame", {
                Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = Color3.fromRGB(120, 215, 255), BorderSizePixel = 0, ZIndex = 62,
            }, track)
            makeDraggable(tGui, tGui)
        end

        roundTimerSet = function(v)
            timerOn = v and true or false
            scanToken = scanToken + 1
            finderRunning = false
            if pgConn then pgConn:Disconnect() pgConn = nil end
            if wsConn then wsConn:Disconnect() wsConn = nil end
            if timerOn then
                buildGui()
                tGui.Visible = true
                lastText, prevSecs, maxSecs = nil, nil, 0
                render()
                local f = quickFind()
                if f then attach(f) else startFinder() end
                -- Oyun sayacı yeniden oluşturursa: bilinen isimlerden biriyle yeni yazı gelirse yakalar
                local function onNew(o)
                    if o.ClassName ~= "TextLabel" or (src and src.Parent) then return end
                    for _, nm in ipairs(NAME_CANDIDATES) do
                        if o.Name == nm then attach(o) return end
                    end
                end
                local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
                if pg then pgConn = pg.DescendantAdded:Connect(onNew) end
                wsConn = workspace.DescendantAdded:Connect(onNew)
            else
                if tGui then tGui.Visible = false end
                detach()
            end
        end

        roundTimerDiag = function()
            if not timerOn then
                notify("Tur Süresi", "Önce 'Tur Süresi Göstergesi'ni aç.", 3)
                return
            end
            local f = quickFind()
            if f then attach(f) end
            if src and src.Parent then
                local msg = src:GetFullName() .. "  →  \"" .. tostring(src.Text) .. "\""
                warn("[EZRAGOX] Tur sayacı kaynağı: " .. msg)
                notify("Tur Süresi", "Sayaç bulundu ✓  Şu an: " .. tostring(src.Text), 4)
            else
                notify("Tur Süresi", "Sayaç henüz bulunamadı, aranıyor... (F9'a ayrıntı yazıldı)", 5)
                startFinder()
                task.spawn(function()
                    local lines = {}
                    local function scanRoot(root, tag)
                        local list = root:GetDescendants()
                        for i = 1, #list do
                            local d = list[i]
                            if d.ClassName == "TextLabel" and #lines < 25 and string.find(d.Text, "%d") and #d.Text < 30 then
                                lines[#lines + 1] = tag .. ":" .. d:GetFullName() .. "  →  \"" .. d.Text .. "\""
                            end
                            if i % 300 == 0 then task.wait() end
                        end
                    end
                    local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
                    if pg then scanRoot(pg, "PlayerGui") end
                    scanRoot(workspace, "Workspace")
                    warn("[EZRAGOX] Sayaç bulunamadı. Rakam içeren yazılar:\n" .. table.concat(lines, "\n"))
                end)
            end
        end
    end

    ---------------------------------------------------------
    -- SAYFA İÇERİĞİ
    ---------------------------------------------------------
    createSection(MM2Page, "MURDER MYSTERY 2  •  ROL ESP")
    createToggle(MM2Page, "🎯  Rol ESP (Katil • Polis • Masum • Kahraman • Düşen Silah)", false, function(v)
        espOn = v
        gunEspOn = v -- Düşen Silah ESP, Rol ESP ile birlikte açılıp kapanır
        if not v then
            clearESP()
            clearGunEsp()
        end
    end)
    createButton(MM2Page, "🔍  Katil Gücü Teşhisi (F9'a Rapor Yaz)", function()
        if Settings.MM2PerkDiagnose then Settings.MM2PerkDiagnose() end
    end)
    createSection(MM2Page, "KATİL = KIRMIZI  •  POLİS = MAVİ  •  MASUM = YEŞİL  •  KAHRAMAN = SARI  •  DÜŞEN SİLAH = TURUNCU")

    ---------------------------------------------------------
    -- 🔪 ATILAN BIÇAK ESP (ayrı özellik) — katil bıçak fırlatınca bıçak KIRMIZI görünür
    ---------------------------------------------------------
    ;(function()
        local KNIFE_COLOR = Color3.fromRGB(255, 25, 25)
        local knifeOn = false
        local items = {}   -- [bıçak nesnesi] = {hl, part, last, still, moved, t0}
        local dead = setmetatable({}, {__mode = "k"})   -- bir yere saplanmış bıçaklar (konumlarıyla)
        local folder

        local function getFolderK()
            if folder and folder.Parent then return folder end
            folder = Instance.new("Folder")
            folder.Name = "EZRAGOX_KnifeESP"
            folder.Parent = ScreenGui.Parent or CoreGui
            return folder
        end

        local function inCharacterOrTool(inst)
            if inst:FindFirstAncestorOfClass("Tool") or inst:FindFirstAncestorOfClass("Backpack") then return true end
            for _, p in ipairs(Players:GetPlayers()) do
                local ch = p.Character
                if ch and inst:IsDescendantOf(ch) then return true end
            end
            return false
        end

        local function isThrownKnife(inst)
            if not (inst:IsA("BasePart") or inst:IsA("Model")) then return false end
            if not inst.Name:lower():find("knife") then return false end
            if inst:IsA("Model") and inst:FindFirstChildOfClass("Humanoid") then return false end
            return not inCharacterOrTool(inst)
        end

        local function partOf(inst)
            if inst:IsA("BasePart") then return inst end
            return inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart", true)
        end

        local function clearKnife(inst)
            local d = items[inst]
            if not d then return end
            pcall(function() d.hl:Destroy() end)
            items[inst] = nil
        end

        local function clearAllKnives()
            for inst in pairs(items) do clearKnife(inst) end
        end

        local function addKnife(inst)
            local part = partOf(inst)
            if not part then return end
            local hl = Instance.new("Highlight")
            hl.Name = "EZRAGOX_KNIFE_HL"
            hl.Adornee = inst
            hl.FillColor, hl.OutlineColor = KNIFE_COLOR, KNIFE_COLOR
            hl.FillTransparency, hl.OutlineTransparency = 0.05, 0
            hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            hl.Parent = getFolderK()

            items[inst] = {hl = hl, part = part, last = part.Position, still = 0, moved = false, t0 = os.clock()}
        end

        task.spawn(function()
            while alive do
                if knifeOn then
                    pcall(function()
                        local seen = {}
                        for _, c in ipairs(workspace:GetChildren()) do
                            local landedAt = dead[c]
                            if landedAt then
                                -- aynı nesne tekrar fırlatılırsa (yeniden kullanım) yeniden göster
                                local pt = partOf(c)
                                if pt and (pt.Position - landedAt).Magnitude > 2 then dead[c] = nil end
                            elseif isThrownKnife(c) then
                                seen[c] = true
                                if not items[c] then addKnife(c) end
                            end
                        end
                        for inst, d in pairs(items) do
                            if not seen[inst] or not inst.Parent or not d.part.Parent then
                                clearKnife(inst)
                            else
                                -- bıçak bir yere değip durduysa ESP kapanır
                                local pos = d.part.Position
                                if (pos - d.last).Magnitude > 0.4 then
                                    d.moved, d.still = true, 0
                                else
                                    d.still = d.still + 1
                                end
                                d.last = pos
                                if (d.moved and d.still >= 3) or (not d.moved and os.clock() - d.t0 > 0.4) then
                                    dead[inst] = pos
                                    clearKnife(inst)
                                end
                            end
                        end
                    end)
                    task.wait(0.05)
                else
                    task.wait(0.3)
                end
            end
            clearAllKnives()
        end)

        createToggle(MM2Page, "🔪  Atılan Bıçak ESP (Katil Fırlatınca Kırmızı)", false, function(v)
            knifeOn = v and true or false
            if not v then clearAllKnives() end
        end)
    end)()

    createSection(MM2Page, "TUR SÜRESİ")
    createToggle(MM2Page, "⏱️  Tur Süresi Göstergesi (Ekranda Sürüklenebilir)", false, function(v)
        roundTimerSet(v)
    end)
    createButton(MM2Page, "🔍  Sayacı Yeniden Bul / Teşhis", function()
        roundTimerDiag()
    end)

    useMM2Category("SHERIFF")
    createSection(MM2Page, "KESKİN VURUŞ")
    createButton(MM2Page, "🔫  Keskin Vuruş (Katil / Zombi) — Şimdi", function()
        shootTarget()
    end)
    keyRow("Keskin Vuruş Tuşu (katil / zombi)", "MM2ShootKey")
    local LEFTCLICK_TOGGLE = "🖱️  Sol Tıkla Keskin Vuruş (Silah Elindeyken)"
    SFX.shootLeftOn = savedOr(LEFTCLICK_TOGGLE, false)
    createToggle(MM2Page, LEFTCLICK_TOGGLE, SFX.shootLeftOn, function(v)
        SFX.shootLeftOn = v
    end)
    createSlider(MM2Page, "🎯  Nişan Öngörüsü (%)  •  mermi arkada kalırsa artır", 0, 200, 100, function(v)
        SFX.leadMul = (tonumber(v) or 100) / 100
    end)
    local PREEQUIP_TOGGLE = "🔫  Silahı Önceden Ele Al (Sheriff Olunca Otomatik)"
    SFX.preEquipOn = savedOr(PREEQUIP_TOGGLE, true)
    createToggle(MM2Page, PREEQUIP_TOGGLE, SFX.preEquipOn, function(v)
        SFX.preEquipOn = v
    end)
    local RETRY_TOGGLE = "🔁  Iskalarsa Otomatik Tekrar Vur"
    SFX.retryOn = savedOr(RETRY_TOGGLE, false)
    createToggle(MM2Page, RETRY_TOGGLE, SFX.retryOn, function(v)
        SFX.retryOn = v
    end)
    -- Silah çantana geçtiği an (tur başı / yerden alınca) bir kez otomatik ele alınır;
    -- sonra elinden bırakırsan tekrar zorla ele alınmaz.
    task.spawn(function()
        while alive do
            pcall(function()
                if not SFX.preEquipOn then return end
                local ch, hum, gun = LocalPlayer.Character, myHum(), findGun()
                if ch and hum and hum.Health > 0 and gun and gun.Parent ~= ch and gun ~= SFX.preGun then
                    SFX.preGun = gun
                    hum:EquipTool(gun)
                end
            end)
            task.wait(0.2)
        end
    end)
    local ZOMBIE_TOGGLE = "🧟  Zombi Modu (Zombilere de Ateş Et)"
    zombieShotOn = savedOr(ZOMBIE_TOGGLE, true)
    createToggle(MM2Page, ZOMBIE_TOGGLE, zombieShotOn, function(v)
        zombieShotOn = v
    end)

    local WALL_TOGGLE = "🧱  Duvar Arkası Vuruş  (👑 PREMİUM)"
    local wallToggle
    wallToggle = createToggle(MM2Page, WALL_TOGGLE, false, function(v)
        if v and not Settings.PremiumActive then
            wallToggle.Set(false, true, true)
            notify("Premium Gerekli", "Duvar arkası vuruş sadece premium kullanıcılar içindir.", 3)
            return
        end
        wallOn = v and true or false
        if v then
            notify("Duvar Arkası Vuruş", "Aktif! Haritada nerede olursan ol, ateş edince katile direkt gider.", 4)
        end
    end, false)
    Settings.PremiumGated = Settings.PremiumGated or {}
    Settings.PremiumGated[#Settings.PremiumGated + 1] = wallToggle
    -- Açılışta görsel olarak kapalı başlasın (kayıtlı durum, premium doğrulanınca geri yüklenir)
    wallToggle.Set(false, true, true)

    ---------------------------------------------------------
    -- 🌈 MERMİ İZİ (RGB)  +  ⚡ VURUŞ EFEKTLERİ (ŞİMŞEK / VURUŞ ANİMASYONU)
    -- Her şey tek bir fonksiyonun içinde tutulur (Lua'nın 200 local sınırına takılmamak için).
    ---------------------------------------------------------
    ;(function()
        -- İstersen buraya kendi gök gürültüsü / şimşek ses ID'ni yaz, örn: "1234567890"
        -- Boş bırakırsan Roblox'un kendi patlama sesi kalın ve yavaş çalınarak gök gürültüsü gibi kullanılır.
        local THUNDER_SOUND_ID = ""

        local fx = {tracer = false, lightning = false, hitAnim = false, fire = false, ice = false, column = false, firework = false, trail = 0.6, vol = 0}
        local fxFolder
        local lastTracerClock, lastShotClock, lastTracerShot = 0, 0, -100
        local murdererName = nil

        local function getFolder()
            if fxFolder and fxFolder.Parent then return fxFolder end
            fxFolder = Instance.new("Folder")
            fxFolder.Name = "EZRAGOX_FX"
            fxFolder.Parent = workspace
            return fxFolder
        end

        local function fxPart(size, color, cf, transparency)
            local p = Instance.new("Part")
            p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
            p.Material = Enum.Material.Neon
            p.Size, p.Color, p.CFrame = size, color, cf
            p.Transparency = transparency or 0
            p.Parent = getFolder()
            return p
        end

        local function hue(h) return Color3.fromHSV(h % 1, 1, 1) end

        local function kill(obj, t)
            task.delay(t, function() pcall(function() obj:Destroy() end) end)
        end

        ---------------------------------------------------------
        -- RGB MERMİ İZİ
        ---------------------------------------------------------
        local function drawTracer(origin, target)
            if not (alive and fx.tracer) then return end
            local now = os.clock()
            if now - lastTracerClock < 0.08 then return end
            if now - lastTracerShot < (Settings.MM2FxCooldown or 1.8) then return end -- silah dolarken izi yok
            lastTracerClock, lastTracerShot = now, now
            local vec = target - origin
            local dist = vec.Magnitude
            if dist < 1 then return end
            local dir = vec.Unit
            local dur = math.max(fx.trail, 0.2) * 1.6       -- duman biraz daha uzun yaşasın
            local base = (now * 0.1) % 1                      -- renk yavaşça kayar
            local SPAN = 0.22                                 -- hafif renk geçişi (tam gökkuşağı değil)
            local function col(t) return Color3.fromHSV((base + t * SPAN) % 1, 0.55, 1) end

            local okAll = pcall(function()
                -- Beam uçları (görünmez, sabit noktalar)
                local a0 = fxPart(Vector3.new(0.1, 0.1, 0.1), Color3.new(1, 1, 1), CFrame.lookAt(origin, target), 1)
                local a1 = fxPart(Vector3.new(0.1, 0.1, 0.1), Color3.new(1, 1, 1), CFrame.lookAt(target, origin), 1)
                local at0, at1 = Instance.new("Attachment"), Instance.new("Attachment")
                at0.Parent, at1.Parent = a0, a1

                -- Uzunlamasına yumuşak renk geçişi
                local kps = {}
                for i = 0, 7 do
                    local t = i / 7
                    kps[#kps + 1] = ColorSequenceKeypoint.new(t, col(t))
                end
                local gradient = ColorSequence.new(kps)

                -- İki katman: ince çekirdek + geniş yumuşak duman gövdesi
                local layers = {
                    {w0 = 0.10, w1 = 0.22, base = 0.45, em = 1.0, curve = 0.8},
                    {w0 = 0.45, w1 = 1.10, base = 0.78, em = 0.6, curve = 2.2},
                }
                local beams = {}
                for _, L in ipairs(layers) do
                    local b = Instance.new("Beam")
                    b.Attachment0, b.Attachment1 = at0, at1
                    b.Color = gradient
                    b.LightEmission = L.em
                    b.LightInfluence = 0
                    b.FaceCamera = true
                    b.Segments = 24
                    b.CurveSize0 = (math.random() - 0.5) * 2 * L.curve
                    b.CurveSize1 = (math.random() - 0.5) * 2 * L.curve
                    b.Width0, b.Width1 = L.w0, L.w1
                    b.Parent = a0
                    beams[#beams + 1] = {b = b, w0 = L.w0, w1 = L.w1, base = L.base}
                end

                local function trSeq(f, baseTr)
                    local function t(x) return math.clamp(x + (1 - x) * f, 0, 1) end
                    return NumberSequence.new({
                        NumberSequenceKeypoint.new(0, 1),
                        NumberSequenceKeypoint.new(0.12, t(baseTr + 0.15)),
                        NumberSequenceKeypoint.new(0.55, t(baseTr)),
                        NumberSequenceKeypoint.new(1, t(baseTr + 0.25)),
                    })
                end
                for _, bi in ipairs(beams) do bi.b.Transparency = trSeq(0, bi.base) end

                -- Zamanla dağılan / genişleyen duman
                task.spawn(function()
                    local t0 = os.clock()
                    while alive do
                        local f = (os.clock() - t0) / dur
                        if f >= 1 then break end
                        local e = f * f
                        local grow = 1 + f * 2.0
                        for _, bi in ipairs(beams) do
                            if bi.b.Parent then
                                bi.b.Transparency = trSeq(e, bi.base)
                                bi.b.Width0, bi.b.Width1 = bi.w0 * grow, bi.w1 * grow
                            end
                        end
                        RunService.Heartbeat:Wait()
                    end
                    pcall(function() a0:Destroy() end)
                    pcall(function() a1:Destroy() end)
                end)
                kill(a0, dur + 0.5)
                kill(a1, dur + 0.5)

                -- Gerçek duman parçacıkları (iz boyunca, aynı renk geçişiyle)
                local n = math.clamp(math.floor(dist / 3.5), 6, 45)
                for i = 0, n do
                    local tt = i / n
                    local pos = origin + dir * (dist * tt)
                    local p = fxPart(Vector3.new(0.2, 0.2, 0.2), Color3.new(1, 1, 1), CFrame.new(pos), 1)
                    local pe = Instance.new("ParticleEmitter")
                    pe.Texture = "rbxasset://textures/particles/smoke_main.dds"
                    pe.Rate = 0
                    pe.Color = ColorSequence.new(col(tt))
                    pe.LightEmission = 0.6
                    pe.LightInfluence = 0
                    pe.Lifetime = NumberRange.new(dur * 0.8, dur * 1.1)
                    pe.Speed = NumberRange.new(0.2, 1.2)
                    pe.SpreadAngle = Vector2.new(180, 180)
                    pe.Rotation = NumberRange.new(0, 360)
                    pe.RotSpeed = NumberRange.new(-25, 25)
                    pe.Size = NumberSequence.new({
                        NumberSequenceKeypoint.new(0, 0.5),
                        NumberSequenceKeypoint.new(1, 2.6),
                    })
                    pe.Transparency = NumberSequence.new({
                        NumberSequenceKeypoint.new(0, 1),
                        NumberSequenceKeypoint.new(0.15, 0.72),
                        NumberSequenceKeypoint.new(1, 1),
                    })
                    pe.Parent = p
                    pe:Emit(1)
                    kill(p, dur * 1.2 + 0.3)
                end
            end)
            if not okAll then
                -- Güvenlik: bir şey olmazsa eski usul düz çizgi
                local p = fxPart(Vector3.new(0.15, 0.15, dist), col(0.5), CFrame.lookAt(origin + vec / 2, target), 0.3)
                TweenService:Create(p, TweenInfo.new(dur), {Transparency = 1}):Play()
                kill(p, dur + 0.15)
            end
        end

        ---------------------------------------------------------
        -- ŞİMŞEK
        ---------------------------------------------------------
        local function playThunder()
            if (fx.vol or 0) <= 0 then return end -- ses 0 ise hiç çalma
            local custom = tostring(THUNDER_SOUND_ID or "")
            local function make(id, speed, vol, delay)
                task.delay(delay or 0, function()
                    local s = Instance.new("Sound")
                    s.Name = "EZRAGOX_Thunder" -- "EZRAGOX_" ile başlayan sesler silah sesi bastırıcıya takılmaz
                    s.SoundId = id
                    s.PlaybackSpeed = speed
                    s.Volume = vol
                    s.Parent = SoundService
                    s:Play()
                    -- Sonuna kadar çalsın (headshot sesiyle aynı anda çalsa da kesilmez)
                    s.Ended:Connect(function() pcall(function() s:Destroy() end) end)
                    kill(s, 40)
                end)
            end
            local v = fx.vol / 2
            if custom ~= "" then
                make(string.find(custom, "rbx") and custom or ("rbxassetid://" .. custom), 1, v, 0)
            else
                make("rbxasset://sounds/impact_explosion_03.mp3", 1.7, v * 0.8, 0)      -- keskin çatırtı
                make("rbxassetid://9114727268", 0.4, v * 1.3, 0.1)                       -- gümbürtü (scriptte zaten kullanılan, yüklendiği bilinen ses; yavaşlatılmış)
            end
        end

        local function screenFlash()
            pcall(function()
                local f = Instance.new("Frame")
                f.Size = UDim2.new(1, 0, 1, 0)
                f.BackgroundColor3 = Color3.fromRGB(225, 235, 255)
                f.BackgroundTransparency = 0.6
                f.BorderSizePixel = 0
                f.ZIndex = 900
                f.Parent = ScreenGui
                TweenService:Create(f, TweenInfo.new(0.4), {BackgroundTransparency = 1}):Play()
                kill(f, 0.5)
            end)
        end

        local function lightningStrike(pos)
            if not alive then return end
            local top = pos + Vector3.new(math.random(-10, 10), 110, math.random(-10, 10))
            local N = 10
            local pts = {top}
            for i = 1, N - 1 do
                local t = i / N
                local amp = 7 * (1 - t * 0.6)
                pts[#pts + 1] = top:Lerp(pos, t) + Vector3.new((math.random() - 0.5) * 2 * amp, 0, (math.random() - 0.5) * 2 * amp)
            end
            pts[#pts + 1] = pos

            local parts, orig = {}, {}
            local function seg(a, b, w, col, tr)
                local d = b - a
                local len = d.Magnitude
                if len < 0.1 then return end
                local p = fxPart(Vector3.new(w, w, len), col, CFrame.lookAt(a + d / 2, b), tr)
                parts[#parts + 1] = p
                orig[p] = tr
            end
            for i = 1, #pts - 1 do
                seg(pts[i], pts[i + 1], 0.6, Color3.fromRGB(240, 247, 255), 0)
                seg(pts[i], pts[i + 1], 2.2, Color3.fromRGB(110, 150, 255), 0.65)
            end
            for _ = 1, 3 do
                local i = math.random(2, N - 2)
                local a = pts[i]
                local e = a + Vector3.new(math.random(-18, 18), -math.random(10, 25), math.random(-18, 18))
                local mid = (a + e) / 2 + Vector3.new(math.random(-4, 4), 0, math.random(-4, 4))
                seg(a, mid, 0.3, Color3.fromRGB(220, 235, 255), 0.1)
                seg(mid, e, 0.3, Color3.fromRGB(220, 235, 255), 0.1)
            end

            -- Çarpma noktası: ışık + kıvılcım
            local hit = fxPart(Vector3.new(1, 1, 1), Color3.new(1, 1, 1), CFrame.new(pos), 1)
            local light = Instance.new("PointLight")
            light.Color, light.Brightness, light.Range = Color3.fromRGB(170, 200, 255), 15, 45
            light.Parent = hit
            TweenService:Create(light, TweenInfo.new(0.7), {Brightness = 0}):Play()
            pcall(function()
                local pe = Instance.new("ParticleEmitter")
                pe.Rate = 0
                pe.Color = ColorSequence.new(Color3.fromRGB(200, 225, 255))
                pe.LightEmission = 1
                pe.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0)})
                pe.Speed = NumberRange.new(25, 45)
                pe.Lifetime = NumberRange.new(0.4, 0.8)
                pe.SpreadAngle = Vector2.new(180, 180)
                pe.Parent = hit
                pe:Emit(40)
            end)
            kill(hit, 1.5)

            screenFlash()
            playThunder()

            -- Çakma / sönme titremesi
            task.spawn(function()
                for _ = 1, 3 do
                    for _, p in ipairs(parts) do p.Transparency = 1 end
                    task.wait(0.05)
                    for _, p in ipairs(parts) do p.Transparency = orig[p] end
                    task.wait(0.07)
                end
                for _, p in ipairs(parts) do
                    TweenService:Create(p, TweenInfo.new(0.3), {Transparency = 1}):Play()
                    kill(p, 0.4)
                end
            end)
        end

        ---------------------------------------------------------
        -- VURUŞ ANİMASYONU
        ---------------------------------------------------------
        local function hitAnimation(ch, pos)
            if not alive then return end
            local col = hue(os.clock() * 0.8)
            -- Vücut parlaması
            if ch then
                pcall(function()
                    local hl = Instance.new("Highlight")
                    hl.Adornee = ch
                    hl.FillColor = Color3.new(1, 1, 1)
                    hl.OutlineColor = Color3.fromRGB(255, 60, 60)
                    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    hl.FillTransparency, hl.OutlineTransparency = 0, 0
                    hl.Parent = getFolder()
                    TweenService:Create(hl, TweenInfo.new(0.7), {FillTransparency = 1, OutlineTransparency = 1}):Play()
                    kill(hl, 0.8)
                end)
            end
            -- Şok dalgası halkaları
            for k = 0, 1 do
                task.delay(k * 0.1, function()
                    local ring = fxPart(Vector3.new(1, 1, 1), hue(os.clock() * 0.8 + k * 0.3), CFrame.new(pos), 0.3)
                    ring.Shape = Enum.PartType.Ball
                    TweenService:Create(ring, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                        Size = Vector3.new(18, 18, 18), Transparency = 1,
                    }):Play()
                    kill(ring, 0.6)
                end)
            end
            -- Yukarı süzülen yazı
            pcall(function()
                local anchor = fxPart(Vector3.new(1, 1, 1), Color3.new(1, 1, 1), CFrame.new(pos), 1)
                local bb = Instance.new("BillboardGui")
                bb.Size = UDim2.new(0, 180, 0, 44)
                bb.StudsOffset = Vector3.new(0, 3, 0)
                bb.AlwaysOnTop = true
                bb.Parent = anchor
                local tl = Instance.new("TextLabel")
                tl.Size = UDim2.new(1, 0, 1, 0)
                tl.BackgroundTransparency = 1
                tl.Text = "💥 VURULDU!"
                tl.Font = Enum.Font.GothamBlack
                tl.TextScaled = true
                tl.TextColor3 = col
                tl.TextStrokeTransparency = 0.2
                tl.Parent = bb
                TweenService:Create(bb, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {StudsOffset = Vector3.new(0, 8, 0)}):Play()
                TweenService:Create(tl, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {TextTransparency = 1, TextStrokeTransparency = 1}):Play()
                kill(anchor, 1.2)
            end)
        end

        ---------------------------------------------------------
        -- YENİ EFEKTLER (şimşekten farklı, sessiz): ateş • buz • enerji sütunu • havai fişek
        ---------------------------------------------------------
        local CSK, NSK = ColorSequenceKeypoint.new, NumberSequenceKeypoint.new

        local function groundAt(pos)
            local rp = RaycastParams.new()
            rp.FilterType = Enum.RaycastFilterType.Exclude
            local ex = {getFolder()}
            for _, pl in ipairs(Players:GetPlayers()) do
                if pl.Character then ex[#ex + 1] = pl.Character end
            end
            rp.FilterDescendantsInstances = ex
            local r = workspace:Raycast(pos + Vector3.new(0, 2, 0), Vector3.new(0, -30, 0), rp)
            return r and (r.Position + Vector3.new(0, 0.15, 0)) or (pos - Vector3.new(0, 3, 0))
        end

        -- Yere yayılan şok dalgası diski
        local function flatRing(pos, color, maxR, t, thick)
            thick = thick or 0.3
            local r = fxPart(Vector3.new(thick, 1, 1), color, CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)), 0.2)
            r.Shape = Enum.PartType.Cylinder
            TweenService:Create(r, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Size = Vector3.new(thick, maxR * 2, maxR * 2), Transparency = 1,
            }):Play()
            kill(r, t + 0.1)
        end

        local function bodyGlow(ch, color, t)
            if not ch then return end
            pcall(function()
                local hl = Instance.new("Highlight")
                hl.Adornee = ch
                hl.FillColor, hl.OutlineColor = color, color
                hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                hl.FillTransparency, hl.OutlineTransparency = 0.2, 0
                hl.Parent = getFolder()
                TweenService:Create(hl, TweenInfo.new(t), {FillTransparency = 1, OutlineTransparency = 1}):Play()
                kill(hl, t + 0.1)
            end)
        end

        -- 🔥 Ateş patlaması
        local function fireBlast(ch, pos)
            if not alive then return end
            bodyGlow(ch, Color3.fromRGB(255, 120, 20), 0.8)
            local g = groundAt(pos)
            flatRing(g, Color3.fromRGB(255, 120, 30), 20, 0.6, 0.3)
            local hit = fxPart(Vector3.new(1, 1, 1), Color3.new(1, 1, 1), CFrame.new(pos), 1)
            local light = Instance.new("PointLight")
            light.Color, light.Brightness, light.Range = Color3.fromRGB(255, 140, 40), 14, 45
            light.Parent = hit
            TweenService:Create(light, TweenInfo.new(0.9), {Brightness = 0}):Play()
            pcall(function()
                local fire = Instance.new("ParticleEmitter")
                fire.Texture = "rbxasset://textures/particles/fire_main.dds"
                fire.Rate = 0
                fire.LightEmission = 1
                fire.LightInfluence = 0
                fire.Color = ColorSequence.new({CSK(0, Color3.fromRGB(255, 235, 130)), CSK(0.5, Color3.fromRGB(255, 110, 20)), CSK(1, Color3.fromRGB(90, 20, 10))})
                fire.Size = NumberSequence.new({NSK(0, 2), NSK(0.4, 5.5), NSK(1, 0)})
                fire.Transparency = NumberSequence.new({NSK(0, 0.1), NSK(1, 1)})
                fire.Speed = NumberRange.new(10, 28)
                fire.Lifetime = NumberRange.new(0.6, 1.2)
                fire.SpreadAngle = Vector2.new(70, 70)
                fire.Rotation = NumberRange.new(0, 360)
                fire.Acceleration = Vector3.new(0, 12, 0)
                fire.Parent = hit
                fire:Emit(50)

                local smoke = Instance.new("ParticleEmitter")
                smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
                smoke.Rate = 0
                smoke.LightInfluence = 0.5
                smoke.Color = ColorSequence.new(Color3.fromRGB(50, 45, 45))
                smoke.Size = NumberSequence.new({NSK(0, 3), NSK(1, 10)})
                smoke.Transparency = NumberSequence.new({NSK(0, 0.5), NSK(1, 1)})
                smoke.Speed = NumberRange.new(4, 12)
                smoke.Lifetime = NumberRange.new(1.2, 2)
                smoke.SpreadAngle = Vector2.new(180, 180)
                smoke.Acceleration = Vector3.new(0, 6, 0)
                smoke.Parent = hit
                smoke:Emit(14)

                local sp = Instance.new("ParticleEmitter")
                sp.Rate = 0
                sp.LightEmission = 1
                sp.Color = ColorSequence.new(Color3.fromRGB(255, 200, 80))
                sp.Size = NumberSequence.new({NSK(0, 0.6), NSK(1, 0)})
                sp.Speed = NumberRange.new(30, 65)
                sp.Lifetime = NumberRange.new(0.6, 1.3)
                sp.SpreadAngle = Vector2.new(180, 180)
                sp.Acceleration = Vector3.new(0, -60, 0)
                sp.Parent = hit
                sp:Emit(45)
            end)
            kill(hit, 2.5)
        end

        -- ❄️ Buz parçalanması
        local function iceShatter(ch, pos)
            if not alive then return end
            bodyGlow(ch, Color3.fromRGB(150, 225, 255), 1.0)
            local g = groundAt(pos)
            flatRing(g, Color3.fromRGB(170, 235, 255), 18, 0.8, 0.25)
            flatRing(g + Vector3.new(0, 0.1, 0), Color3.fromRGB(255, 255, 255), 10, 0.5, 0.2)
            for _ = 1, 18 do
                local size = Vector3.new(0.35 + math.random() * 0.5, 1 + math.random() * 1.5, 0.35 + math.random() * 0.5)
                local p = fxPart(size, Color3.fromRGB(170, 235, 255),
                    CFrame.new(pos + Vector3.new(0, 0.5, 0)) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6), 0.15)
                p.Anchored = false
                local ang, sp = math.random() * math.pi * 2, 12 + math.random() * 14
                p.AssemblyLinearVelocity = Vector3.new(math.cos(ang) * sp, 18 + math.random() * 16, math.sin(ang) * sp)
                p.AssemblyAngularVelocity = Vector3.new((math.random() - 0.5) * 30, (math.random() - 0.5) * 30, (math.random() - 0.5) * 30)
                TweenService:Create(p, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Transparency = 1}):Play()
                kill(p, 1.3)
            end
            local hit = fxPart(Vector3.new(1, 1, 1), Color3.new(1, 1, 1), CFrame.new(pos), 1)
            pcall(function()
                local pe = Instance.new("ParticleEmitter")
                pe.Rate = 0
                pe.LightEmission = 1
                pe.Color = ColorSequence.new(Color3.fromRGB(190, 240, 255), Color3.fromRGB(255, 255, 255))
                pe.Size = NumberSequence.new({NSK(0, 0.9), NSK(1, 0)})
                pe.Speed = NumberRange.new(8, 24)
                pe.Lifetime = NumberRange.new(0.8, 1.6)
                pe.SpreadAngle = Vector2.new(180, 180)
                pe.Acceleration = Vector3.new(0, -8, 0)
                pe.Parent = hit
                pe:Emit(60)
            end)
            kill(hit, 2)
        end

        -- 🌠 Enerji sütunu (gökyüzüne yükselen ışık + yükselen halkalar)
        local function energyColumn(pos)
            if not alive then return end
            local g = groundAt(pos)
            local h0 = math.random()
            local col = fxPart(Vector3.new(120, 5, 5), hue(h0), CFrame.new(g + Vector3.new(0, 60, 0)) * CFrame.Angles(0, 0, math.rad(90)), 0.2)
            col.Shape = Enum.PartType.Cylinder
            TweenService:Create(col, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Size = Vector3.new(120, 0.4, 0.4), Transparency = 1,
            }):Play()
            kill(col, 1.2)
            flatRing(g, hue(h0 + 0.15), 16, 0.7, 0.3)
            for k = 0, 2 do
                task.delay(k * 0.12, function()
                    if not alive then return end
                    local ring = fxPart(Vector3.new(0.25, 14, 14), hue(h0 + 0.2 + k * 0.12), CFrame.new(g) * CFrame.Angles(0, 0, math.rad(90)), 0.3)
                    ring.Shape = Enum.PartType.Cylinder
                    TweenService:Create(ring, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                        CFrame = CFrame.new(g + Vector3.new(0, 45, 0)) * CFrame.Angles(0, 0, math.rad(90)),
                        Size = Vector3.new(0.25, 3, 3), Transparency = 1,
                    }):Play()
                    kill(ring, 1)
                end)
            end
            local hit = fxPart(Vector3.new(1, 1, 1), Color3.new(1, 1, 1), CFrame.new(g + Vector3.new(0, 2, 0)), 1)
            local light = Instance.new("PointLight")
            light.Color, light.Brightness, light.Range = hue(h0), 12, 40
            light.Parent = hit
            TweenService:Create(light, TweenInfo.new(1), {Brightness = 0}):Play()
            kill(hit, 1.4)
        end

        -- 🎆 Havai fişek (gökyüzünde 3 renkli patlama)
        local function fireworkBurst(pos)
            if not alive then return end
            local rocket = fxPart(Vector3.new(0.4, 3, 0.4), Color3.fromRGB(255, 240, 200), CFrame.new(pos), 0)
            TweenService:Create(rocket, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                CFrame = CFrame.new(pos + Vector3.new(0, 26, 0)), Transparency = 1,
            }):Play()
            kill(rocket, 0.4)
            for k = 0, 2 do
                task.delay(0.25 + k * 0.22, function()
                    if not alive then return end
                    local c = pos + Vector3.new(math.random(-9, 9), 26 + math.random(0, 10), math.random(-9, 9))
                    local anchor = fxPart(Vector3.new(0.5, 0.5, 0.5), Color3.new(1, 1, 1), CFrame.new(c), 1)
                    local h = math.random()
                    pcall(function()
                        local pe = Instance.new("ParticleEmitter")
                        pe.Rate = 0
                        pe.LightEmission = 1
                        pe.LightInfluence = 0
                        pe.Color = ColorSequence.new(Color3.fromHSV(h, 0.85, 1), Color3.fromHSV((h + 0.35) % 1, 0.85, 1))
                        pe.Size = NumberSequence.new({NSK(0, 1.3), NSK(1, 0)})
                        pe.Transparency = NumberSequence.new({NSK(0, 0), NSK(0.7, 0.2), NSK(1, 1)})
                        pe.Speed = NumberRange.new(22, 48)
                        pe.Lifetime = NumberRange.new(1.0, 1.6)
                        pe.SpreadAngle = Vector2.new(180, 180)
                        pe.Acceleration = Vector3.new(0, -22, 0)
                        pe.Drag = 1.5
                        pe.Parent = anchor
                        pe:Emit(70)
                    end)
                    local light = Instance.new("PointLight")
                    light.Color, light.Brightness, light.Range = Color3.fromHSV(h, 0.7, 1), 10, 60
                    light.Parent = anchor
                    TweenService:Create(light, TweenInfo.new(0.8), {Brightness = 0}):Play()
                    kill(anchor, 2.2)
                end)
            end
        end

        local function anyKillFx()
            return fx.lightning or fx.hitAnim or fx.fire or fx.ice or fx.column or fx.firework
        end

        ---------------------------------------------------------
        -- TETİKLEYİCİLER
        ---------------------------------------------------------
        -- Script ile (Keskin Vuruş / Duvar Arkası) atılan atışlar fireGunAt içinden buraya haber verir
        Settings.PXShot = function(origin, pos)
            lastShotClock = os.clock()
            drawTracer(origin, pos)
        end

        -- Normal silah tıklamaları
        local mouse = LocalPlayer:GetMouse()
        bind(UserInputService.InputBegan, function(input, gpe)
            if gpe then return end
            if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
            local gun = findGun()
            if not (gun and gun.Parent == LocalPlayer.Character) then return end
            lastShotClock = os.clock()
            if not fx.tracer then return end
            task.delay(0.12, function()
                if os.clock() - lastTracerClock < 0.3 then return end -- script zaten çizdi
                local handle = gun:FindFirstChild("Handle")
                local o = (handle and handle:IsA("BasePart") and handle.Position) or (myHRP() and myHRP().Position)
                if not o then return end
                local ok, hp = pcall(function() return mouse.Hit.Position end)
                if not ok or not hp then return end
                local d = hp - o
                if d.Magnitude > 300 then hp = o + d.Unit * 300 end
                drawTracer(o, hp)
            end)
        end)

        -- Katil vurulunca (atışımızdan hemen sonra ölünce) efektleri çalıştır
        local function onDown(plr, ch)
            if not anyKillFx() then return end
            if os.clock() - lastShotClock > 1.8 then return end
            local isM = (plr.Name == murdererName)
            if not isM then
                local bp = plr:FindFirstChildOfClass("Backpack")
                isM = (ch and ch:FindFirstChild("Knife") ~= nil) or (bp and bp:FindFirstChild("Knife") ~= nil) or false
            end
            if not isM then return end
            local hrp = ch and (ch:FindFirstChild("HumanoidRootPart") or ch:FindFirstChild("Torso"))
            if not hrp then return end
            local pos = hrp.Position
            if fx.hitAnim then hitAnimation(ch, pos) end
            if fx.lightning then task.delay(0.1, lightningStrike, pos) end
            if fx.fire then fireBlast(ch, pos) end
            if fx.ice then iceShatter(ch, pos) end
            if fx.column then energyColumn(pos) end
            if fx.firework then fireworkBurst(pos) end
        end

        local function hookPlayer(p)
            if p == LocalPlayer then return end
            local function hookChar(ch)
                local h = ch:WaitForChild("Humanoid", 5)
                if h then bind(h.Died, function() onDown(p, ch) end) end
            end
            if p.Character then task.spawn(hookChar, p.Character) end
            bind(p.CharacterAdded, function(ch) task.spawn(hookChar, ch) end)
        end
        for _, p in ipairs(Players:GetPlayers()) do hookPlayer(p) end
        bind(Players.PlayerAdded, hookPlayer)

        -- Katilin kim olduğunu efektler açıkken arada bir güncelle
        task.spawn(function()
            while alive do
                if anyKillFx() then
                    local ok, m = pcall(findRole, "Murderer", true)
                    if ok and m then murdererName = m.Name end
                end
                task.wait(1.5)
            end
        end)

        ---------------------------------------------------------
        -- ARAYÜZ
        ---------------------------------------------------------
        createSection(MM2Page, "MERMİ İZİ  •  VURUŞ EFEKTLERİ")
        createToggle(MM2Page, "🌈  Mermi İzi (RGB)", false, function(v) fx.tracer = v end)
        createSlider(MM2Page, "⏱️  İz Süresi", 2, 20, 6, function(v) fx.trail = v * 0.1 end)
        createToggle(MM2Page, "💥  Vuruş Animasyonu (Katil Vurulunca)", false, function(v) fx.hitAnim = v end)
        createToggle(MM2Page, "⚡  Şimşek Çarpması (Katil Vurulunca)", false, function(v) fx.lightning = v end)
        createToggle(MM2Page, "🔥  Ateş Patlaması (Katil Vurulunca)", false, function(v) fx.fire = v end)
        createToggle(MM2Page, "❄️  Buz Parçalanması (Katil Vurulunca)", false, function(v) fx.ice = v end)
        createToggle(MM2Page, "🌠  Enerji Sütunu (Katil Vurulunca)", false, function(v) fx.column = v end)
        createToggle(MM2Page, "🎆  Havai Fişek (Katil Vurulunca)", false, function(v) fx.firework = v end)
        createSlider(MM2Page, "🔊  Şimşek Sesi (0 = Sessiz)", 0, 10, 0, function(v) fx.vol = v end)
        createButton(MM2Page, "⚡  Efekt Testi (Önüne Şimşek Çaktır)", function()
            local hrp = myHRP()
            if not hrp then return end
            local p = hrp.Position + hrp.CFrame.LookVector * 18
            local rp = RaycastParams.new()
            rp.FilterType = Enum.RaycastFilterType.Exclude
            rp.FilterDescendantsInstances = {LocalPlayer.Character}
            local r = workspace:Raycast(p + Vector3.new(0, 50, 0), Vector3.new(0, -120, 0), rp)
            local pos = r and r.Position or p
            hitAnimation(nil, pos)
            lightningStrike(pos)
            if fx.fire then fireBlast(nil, pos) end
            if fx.ice then iceShatter(nil, pos) end
            if fx.column then energyColumn(pos) end
            if fx.firework then fireworkBurst(pos) end
        end)
        createButton(MM2Page, "✨  Yeni Efektleri Dene (Ateş • Buz • Sütun • Havai Fişek)", function()
            local hrp = myHRP()
            if not hrp then return end
            local right, look = hrp.CFrame.RightVector, hrp.CFrame.LookVector
            local base = hrp.Position + look * 22
            fireBlast(nil, base - right * 14)
            iceShatter(nil, base - right * 5)
            energyColumn(base + right * 5)
            fireworkBurst(base + right * 14)
        end)
    end)()

    useMM2Category("KATİL")
    ---------------------------------------------------------
    -- BIÇAK ATMA: tuşa basınca en yakındaki oyuncuya hızlıca bıçak at
    ---------------------------------------------------------
    function SFX.findThrowRemote(knife)
        for _, d in ipairs(knife:GetDescendants()) do
            if isRemote(d) and string.find(string.lower(d.Name), "throw", 1, true) then return d end
        end
        return nil
    end

    -- En yakın (tercihen görüş hattı olan) canlı oyuncuyu seç
    function SFX.nearestVictim()
        local me = myHRP()
        if not me then return nil end
        local list = {}
        for _, pl in ipairs(Players:GetPlayers()) do
            local ch = pl ~= LocalPlayer and pl.Character
            local hum = ch and ch:FindFirstChildOfClass("Humanoid")
            local part = ch and targetPartOf(ch)
            if hum and part and hum.Health > 0 and isAlive(pl) then
                list[#list + 1] = {part = part, hum = hum, d = (part.Position - me.Position).Magnitude}
            end
        end
        table.sort(list, function(x, y) return x.d < y.d end)
        for _, e in ipairs(list) do
            if SFX.targetVisible(me.Position, e.part, aimPoint(e.part, e.hum)) then return e end
        end
        return list[1]
    end

    -- Bıçağın uçuş süresi kadar ek öngörü + ping öngörüsü (aimPoint)
    function SFX.knifeAim(e)
        local base = aimPoint(e.part, e.hum)
        local v = measuredVelocity(e.part) or e.part.AssemblyLinearVelocity
        local flat = Vector3.new(v.X, 0, v.Z)
        if flat.Magnitude < 1.2 then return base end
        local extra = flat * (e.d / 110)
        if extra.Magnitude > 14 then extra = extra.Unit * 14 end
        return base + extra
    end

    SFX.lastKnifeWarn = 0
    function SFX.throwNearest()
        if os.clock() - (SFX.lastThrow or 0) < 0.25 then return end
        local knife = findKnife()
        local ch = LocalPlayer.Character
        if not (knife and ch and myHRP()) then
            if os.clock() - SFX.lastKnifeWarn > 2 then
                SFX.lastKnifeWarn = os.clock()
                pcall(notifyTop, "🔪 Bıçak atmak için katil olmalısın.", 3)
            end
            return
        end
        SFX.lastThrow = os.clock()
        -- Bıçağı hemen ele almaya başla; hedef seçimi aynı anda ilerlesin
        local hum0 = myHum()
        if hum0 and knife.Parent ~= ch then pcall(function() hum0:EquipTool(knife) end) end
        local victim = SFX.nearestVictim()
        if not victim then
            pcall(notifyTop, "🔪 Atılacak oyuncu bulunamadı.", 2)
            return
        end
        task.spawn(function()
            local t0 = os.clock()
            while knife.Parent ~= ch and os.clock() - t0 < 0.6 and alive do task.wait() end
            if knife.Parent ~= ch then return end
            if t0 and os.clock() - t0 > 0.02 then task.wait(0.05) end -- bıçak betiği hazır olsun
            local remote = SFX.findThrowRemote(knife)
            if not remote then
                pcall(notifyTop, "🔪 Bıçakta atma remote'u bulunamadı. Bir kez elle bıçak at, script öğrensin.", 5)
                return
            end
            if not (victim.part.Parent and victim.hum.Health > 0) then return end
            local handle = knife:FindFirstChild("Handle")
            local hrp = myHRP()
            local origin = (hrp and hrp.Position) or (handle and handle.Position)
            if not origin then return end
            local aim = SFX.knifeAim(victim) -- gönderim anında yeniden hesapla
            local args
            local rec = learned["Throw"]
            if rec then
                args = withPos(rec.args, aim, origin)
            else
                args = table.pack(CFrame.new(origin), CFrame.new(aim))
            end
            pcall(function()
                if remote:IsA("RemoteFunction") then
                    remote:InvokeServer(table.unpack(args, 1, args.n))
                else
                    remote:FireServer(table.unpack(args, 1, args.n))
                end
            end)
        end)
    end

    createSection(MM2Page, "BIÇAK ATMA  (EN YAKINDAKİ OYUNCUYA)")
    do
    local KNIFE_TOGGLE = "🔪  Bıçak Atma  (Tuşla En Yakındakine Hızlıca At)"
    SFX.knifeOn = savedOr(KNIFE_TOGGLE, false)
    createToggle(MM2Page, KNIFE_TOGGLE, SFX.knifeOn, function(v)
        SFX.knifeOn = v
    end)
    end
    keyRow("Bıçak Atma Tuşu", "MM2KnifeKey")
    createButton(MM2Page, "🔪  En Yakındakine Bıçak At — Şimdi", function()
        SFX.throwNearest()
    end)
    -- Özellik açıkken bıçak çantana geçince bir kez otomatik ele alınır (atış daha hızlı olsun)
    task.spawn(function()
        while alive do
            pcall(function()
                if not SFX.knifeOn then return end
                local ch, hum, k = LocalPlayer.Character, myHum(), findKnife()
                if ch and hum and hum.Health > 0 and k and k.Parent ~= ch and k ~= SFX.preKnife then
                    SFX.preKnife = k
                    hum:EquipTool(k)
                end
            end)
            task.wait(0.25)
        end
    end)

    createSection(MM2Page, "ÖLDÜRME  (KATİL: BIÇAK  •  POLİS: SİLAH)")
    local selRow = baseRow(MM2Page, "Frame", 48)
    rowLabel(selRow, "🎯  Oyuncu Seç")
    local selBox = new("TextBox", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.new(0, 180, 0, 32),
        BackgroundColor3 = Color3.fromRGB(28, 34, 54), Text = "", PlaceholderText = "İsim yaz (örn: hasan)",
        PlaceholderColor3 = Color3.fromRGB(120, 134, 170), TextColor3 = Color3.fromRGB(220, 230, 245),
        TextSize = 12, Font = Enum.Font.GothamBold, ClearTextOnFocus = false, ZIndex = 4,
    }, selRow)
    corner(selBox, 8)
    stroke(selBox, 1, Color3.fromRGB(55, 65, 95), 0.3)
    local selList = new("ScrollingFrame", {
        LayoutOrder = nextOrder(MM2Page), Size = UDim2.new(1, 0, 0, 0),
        BackgroundColor3 = Color3.fromRGB(15, 18, 28), BackgroundTransparency = 0.05, BorderSizePixel = 0,
        ScrollBarThickness = 3, CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Visible = false, ZIndex = 20,
    }, MM2Page)
    corner(selList, 10)
    stroke(selList, 1, Color3.fromRGB(60, 75, 110), 0.2)
    new("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4)}, selList)
    new("UIPadding", {PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6)}, selList)

    local selSuppress = false
    Settings.PlayerPreviewBind(selList)
    local function hideSelList()
        selList.Visible = false
        selList.Size = UDim2.new(1, 0, 0, 0)
    end
    local function updateSelList(filter)
        Settings.PlayerPreview(nil)
        for _, c in ipairs(selList:GetChildren()) do
            if c:IsA("TextButton") then c:Destroy() end
        end
        filter = string.lower(filter or "")
        local count = 0
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer then
                local nm, dn = string.lower(plr.Name), string.lower(plr.DisplayName)
                if filter == "" or string.find(nm, filter, 1, true) or string.find(dn, filter, 1, true) then
                    count = count + 1
                    local b = new("TextButton", {
                        Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = Color3.fromRGB(22, 27, 42),
                        BackgroundTransparency = 0.2, AutoButtonColor = false, Text = "", ZIndex = 21,
                    }, selList)
                    corner(b, 8)
                    b.MouseEnter:Connect(function()
                        tween(b, 0.12, {BackgroundTransparency = 0})
                        Settings.PlayerPreview(plr)
                    end)
                    b.MouseLeave:Connect(function()
                        tween(b, 0.18, {BackgroundTransparency = 0.2})
                        Settings.PlayerPreview(nil)
                    end)
                    local av = new("ImageLabel", {
                        Position = UDim2.new(0, 4, 0, 2), Size = UDim2.new(0, 32, 0, 32), BackgroundTransparency = 1, ZIndex = 22,
                        Image = string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=48&h=48", plr.UserId),
                    }, b)
                    pill(av)
                    new("TextLabel", {
                        Position = UDim2.new(0, 42, 0, 0), Size = UDim2.new(1, -45, 1, 0), BackgroundTransparency = 1,
                        Text = plr.DisplayName .. " (@" .. plr.Name .. ")", TextColor3 = Color3.new(1, 1, 1),
                        TextSize = 12, Font = Enum.Font.GothamMedium, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 22,
                    }, b)
                    bind(b.MouseButton1Click, function()
                        playClickSound()
                        mm2Target = plr
                        selSuppress = true
                        setText(selBox, plr.Name)
                        selSuppress = false
                        hideSelList()
                    end)
                end
            end
        end
        if count > 0 then
            selList.Visible = true
            tween(selList, 0.2, {Size = UDim2.new(1, 0, 0, math.min(count * 40 + 12, 160))})
        else
            hideSelList()
        end
    end
    bind(selBox.Focused, function() updateSelList(selBox.Text) end)
    bind(selBox:GetPropertyChangedSignal("Text"), function()
        if not selSuppress and selBox:IsFocused() then updateSelList(selBox.Text) end
    end)

    createButton(MM2Page, "🔪  Seçili Oyuncuyu Öldür", function()
        killPlayer(currentTarget())
    end)
    createButton(MM2Page, "💀  Herkesi Öldür (Kill All)", function()
        killAll()
    end)

    ---------------------------------------------------------
    -- KILL AURA (KATİL: yakındakilere bıçak • POLİS/KAHRAMAN: menzildeki katile ateş)
    ---------------------------------------------------------
    createSection(MM2Page, "☠️  KILL AURA")
    do
        local auraOn = false
        local auraRange, auraDelay, auraMode, auraTp = 15, 0.3, 1, false
        local MODES = {"Herkes", "Sadece Polis / Kahraman", "Sadece Masumlar"}
        local lastAuraShot = 0

        local lastRealStab = 0
        local MIN_STAB_GAP = 0.5 -- bu sureden sik gercek vurus yapma (oyunun anti-cheat'i yere dusurmesin diye)

        -- Vurus sirasinda/sonrasinda "yere dusme" (ragdoll/PlatformStand) olursa aninda duzeltir
        local function unragdollMe()
            pcall(function()
                local hum = myHum()
                if not hum then return end
                if hum.PlatformStand then hum.PlatformStand = false end
                if hum.Sit then hum.Sit = false end
                local st = hum:GetState()
                if st == Enum.HumanoidStateType.Ragdoll or st == Enum.HumanoidStateType.Physics
                    or st == Enum.HumanoidStateType.FallingDown or st == Enum.HumanoidStateType.GettingUp then
                    pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)
                end
            end)
        end

        local function auraStep()
            if killBusy then return end
            local hrp, hum = myHRP(), myHum()
            if not hrp or not hum or hum.Health <= 0 then return end
            local knife = findKnife()
            local roles = fetchRoles()

            if knife then
                -- Gercek bicak vurusunu guvenli bir hiza sinirla: cok hizli Activate() cagirmak
                -- bazi oyunlarda anti-cheat tarafindan "yere dusurme" (ragdoll) cezasi getiriyor.
                if os.clock() - lastRealStab < MIN_STAB_GAP then return end
                -- En yakın uygun hedefi seç
                local best, bestD
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and targetAlive(p) then
                        local th = p.Character:FindFirstChild("HumanoidRootPart")
                        if th then
                            local d = (th.Position - hrp.Position).Magnitude
                            if d <= auraRange and (not bestD or d < bestD) then
                                local info = roles[p.Name]
                                local ok = not (info and info.Dead)
                                if ok and auraMode == 2 then
                                    ok = info ~= nil and (info.Role == "Sheriff" or info.Role == "Hero")
                                elseif ok and auraMode == 3 then
                                    ok = info == nil or info.Role == "Innocent"
                                end
                                if ok then best, bestD = p, d end
                            end
                        end
                    end
                end
                if not best then return end
                lastRealStab = os.clock()
                killBusy = true
                pcall(function()
                    if knife.Parent ~= LocalPlayer.Character then equipTool(knife) end
                    local th = best.Character and best.Character:FindFirstChild("HumanoidRootPart")
                    local me = myHRP()
                    if not th or not me then return end
                    local origin
                    if bestD > 9 and auraTp then
                        origin = me.CFrame -- uzak hedef: yaklaş, vur, geri dön
                        me.CFrame = CFrame.lookAt((th.CFrame * CFrame.new(0, 0, 2.2)).Position, th.Position)
                        me.AssemblyLinearVelocity = Vector3.zero
                    end
                    local stab = knife:FindFirstChild("Stab")
                    if stab then pcall(function() callRemote(stab, "Slash") end) end
                    pcall(function() knife:Activate() end)
                    pcall(function()
                        local handle = knife:FindFirstChild("Handle")
                        if firetouchinterest and handle then
                            firetouchinterest(th, handle, 0)
                            firetouchinterest(th, handle, 1)
                        end
                    end)
                    if origin then
                        task.wait(0.12)
                        local m2 = myHRP()
                        if m2 then m2.CFrame = origin end
                    end
                end)
                killBusy = false
                unragdollMe()
                task.delay(0.15, unragdollMe) -- gecikmeli ragdoll ihtimaline karsi ikinci kontrol
            elseif findGun() then
                -- Polis / kahraman: menzildeki katile ateş et (silah bekleme süresine saygı gösterir)
                if os.clock() - lastAuraShot < 1.5 then return end
                local m = findRole("Murderer", true)
                local th = m and m.Character and m.Character:FindFirstChild("HumanoidRootPart")
                if th and (th.Position - hrp.Position).Magnitude <= auraRange * 2 then
                    lastAuraShot = os.clock()
                    killBusy = true
                    pcall(fireGunAt, th.Position + th.AssemblyLinearVelocity * getPingSeconds())
                    killBusy = false
                end
            end
        end

        local auraToggle
        auraToggle = createToggle(MM2Page, "☠️  Kill Aura  (Yakındakileri Otomatik Öldür)", false, function(v)
            auraOn = v
        end, false)
        auraToggle.Set(false, true) -- kill aura her açılışta kapalı başlar

        createSection(MM2Page, "KILL AURA AYARLARI")
        createSlider(MM2Page, "📏  Aura Menzili", 5, 40, auraRange, function(v)
            auraRange = v
        end, " st")
        createSlider(MM2Page, "⚡  Vuruş Aralığı (düşük = hızlı)", 1, 10, 3, function(v)
            auraDelay = v / 10 -- 0.1 sn ... 1.0 sn
        end, " /10 sn")

        local row, st = baseRow(MM2Page, "TextButton", 42)
        rowLabel(row, "🎯  Hedef Seçimi")
        local valLbl = new("TextLabel", {
            AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.new(0, 190, 0, 26),
            BackgroundTransparency = 1, Text = MODES[auraMode], Font = Enum.Font.GothamBold, TextSize = 13,
            TextColor3 = Color3.fromRGB(255, 65, 75), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 4,
        }, row)
        hoverFx(row, st)
        bind(row.MouseButton1Click, function()
            playClickSound()
            auraMode = auraMode % #MODES + 1
            setText(valLbl, MODES[auraMode])
        end)

        createToggle(MM2Page, "🌀  Uzak Hedefe Işınlanıp Vur  (Kapalıysa Yerinde Vurur)", false, function(v)
            auraTp = v
        end, false)

        task.spawn(function()
            while alive do
                if auraOn then
                    pcall(auraStep)
                    task.wait(auraDelay)
                else
                    task.wait(0.4)
                end
            end
        end)
    end

    ---------------------------------------------------------
    -- MM2 SES SİSTEMİ • OYUN İÇİ SİLAH SESİ + HEADSHOT SESİ
    --  • Listeden seçtiğin silah sesi, ATEŞ EDERKEN çalar; silahın kendi sesi
    --    susturulur. "Orijinal Ses" seçilince silah eski haline döner.
    --  • Katile isabet edince headshot sesi (%20) çalar.
    --  • Liste kapalı başlar; başlığa tıklayınca aşağı doğru açılır.
    ---------------------------------------------------------
    useMM2Category("SHERIFF")
    createSection(MM2Page, "SİLAH SESLERİ  •  OYUN İÇİ SES")
    ;(function() -- local limiti (200) asimini onlemek icin kendi fonksiyonunda calisir
        local Debris = game:GetService("Debris")
        local GUN_SOUNDS = {
            {name = "Orijinal Ses (Oyunun Kendi Silah Sesi)"},
            {name = "1. Ses • 9114729026", id = 9114729026},
            {name = "2. Ses • 9114692143", id = 9114692143},
            {name = "3. Ses • 103900362811995", id = 103900362811995},
            {name = "4. Ses • 97666147602399", id = 97666147602399},
            {name = "5. Ses • 9114727268", id = 9114727268},
        }
        local GUN_VOL, HEAD_ID, HEAD_VOL = 0.7, 136970527093357, 0.2
        -- Roblox'un varsayılan karakter sesleri (adım, zıplama...) asla susturulmaz
        local SKIP_NAMES = {Running = true, Jumping = true, Landing = true, Climbing = true,
            GettingUp = true, FreeFalling = true, Splash = true, Swimming = true}
        local muted = setmetatable({}, {__mode = "k"}) -- [Sound] = {vol=, conn=}
        local knownIds = {}                            -- susturulan atış seslerinin ID'leri
        local previewSound

        local function isOurs(s)
            return string.sub(s.Name, 1, 8) == "EZRAGOX_"
        end

        local function playSfx(id, vol)
            local s = Instance.new("Sound")
            s.Name = "EZRAGOX_MM2_SFX"
            s.SoundId = "rbxassetid://" .. tostring(id)
            s.Volume = vol
            s.Looped = false
            s.Parent = SoundService
            s:Play()
            -- Süre dolunca değil, ses BİTİNCE silinir (uzun sesler yarıda kesilmesin); 60 sn güvenlik sınırı
            s.Ended:Connect(function() pcall(function() s:Destroy() end) end)
            Debris:AddItem(s, 60)
            return s
        end
        -- Headshot sesi ilk çalışta gecikmesin / eksik kalmasın diye önceden yükle
        task.spawn(function()
            pcall(function() game:GetService("ContentProvider"):PreloadAsync({"rbxassetid://" .. tostring(HEAD_ID)}) end)
        end)

        local function stopPreview()
            if previewSound then
                pcall(function() previewSound:Stop() previewSound:Destroy() end)
                previewSound = nil
            end
        end
        local function playMM2Preview(assetId, volume)
            stopPreview()
            local s = Instance.new("Sound")
            s.Name = "EZRAGOX_MM2_SoundPreview"
            s.SoundId = "rbxassetid://" .. tostring(assetId)
            s.Volume = volume or 0.7
            s.Looped = false
            s.Parent = SoundService
            previewSound = s
            s:Play()
            s.Ended:Connect(function()
                if previewSound == s then previewSound = nil end
                s:Destroy()
            end)
        end

        -- Başka bir oyuncunun karakterinin içinde mi? (onların sesine dokunma)
        local function inOtherChar(s)
            local m = s.Parent
            while m and m ~= workspace do
                if m:IsA("Model") then
                    local pl = Players:GetPlayerFromCharacter(m)
                    if pl then return pl ~= LocalPlayer end
                end
                m = m.Parent
            end
            return false
        end

        -- Sesi sustur (özgün ses seviyesi saklanır, "Orijinal"e dönünce geri verilir)
        local function hush(s)
            local rec = muted[s]
            if not rec then
                rec = {vol = s.Volume}
                muted[s] = rec
                rec.conn = s:GetPropertyChangedSignal("Volume"):Connect(function()
                    if alive and SFX.sel ~= 0 and s.Volume ~= 0 then
                        rec.vol = s.Volume
                        s.Volume = 0
                    end
                end)
            end
            if SFX.sel ~= 0 and s.Volume ~= 0 then
                rec.vol = s.Volume
                s.Volume = 0
            end
            if s.SoundId ~= "" then knownIds[s.SoundId] = true end
        end

        local function restoreAll()
            for s, rec in pairs(muted) do
                if rec.conn then rec.conn:Disconnect() rec.conn = nil end
                if s.Parent then pcall(function() s.Volume = rec.vol end) end
                muted[s] = nil
            end
        end

        local function myGuns()
            local out = {}
            local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
            for _, root in ipairs({LocalPlayer.Character, bp}) do
                local g = root and root:FindFirstChild("Gun")
                if g and g:IsA("Tool") then out[#out + 1] = g end
            end
            return out
        end

        -- Silahın içindeki TÜM sesler + karakterde daha önce susturulmuş ID'ler
        local function scanGun()
            for _, g in ipairs(myGuns()) do
                for _, d in ipairs(g:GetDescendants()) do
                    if d:IsA("Sound") and not isOurs(d) then hush(d) end
                end
            end
            local ch = LocalPlayer.Character
            if ch and next(knownIds) ~= nil then
                for _, d in ipairs(ch:GetDescendants()) do
                    if d:IsA("Sound") and not isOurs(d) and not SKIP_NAMES[d.Name] and knownIds[d.SoundId] then
                        hush(d)
                    end
                end
            end
        end

        local function looksLikeShot(name)
            name = string.lower(name)
            for _, w in ipairs({"shot", "shoot", "gun", "fire", "bang", "pistol", "revolver", "blast"}) do
                if string.find(name, w, 1, true) then return true end
            end
            return false
        end

        -- Atış anında çalmakta olan (yeni başlamış) atış seslerini yakala
        local function scanPlaying()
            if SFX.sel == 0 or not alive then return end
            local roots = {LocalPlayer.Character, LocalPlayer:FindFirstChildOfClass("Backpack"),
                SoundService, LocalPlayer:FindFirstChildOfClass("PlayerGui")}
            for _, r in ipairs(roots) do
                if r then
                    for _, d in ipairs(r:GetDescendants()) do
                        if d:IsA("Sound") and d.Playing and not d.Looped and d.TimePosition < 0.5
                            and d.Volume > 0 and not isOurs(d) and not SKIP_NAMES[d.Name] then
                            local inChar = LocalPlayer.Character and d:IsDescendantOf(LocalPlayer.Character)
                            local inBp = r.ClassName == "Backpack"
                            if inChar or inBp or looksLikeShot(d.Name) then
                                hush(d) -- kalıcı sustur
                            else
                                -- emin değiliz: sadece bu çalışı sustur, kısa süre sonra geri ver
                                local v = d.Volume
                                d.Volume = 0
                                task.delay(1.2, function()
                                    if d.Parent and SFX.sel ~= 0 and d.Volume == 0 then d.Volume = v end
                                end)
                            end
                        end
                    end
                end
            end
        end

        -- Atıştan hemen sonra oluşturulan yeni sesleri (klonlar) sustur
        local function onNewSound(s)
            if not alive or SFX.sel == 0 or not s:IsA("Sound") or isOurs(s) then return end
            local tool = s:FindFirstAncestorOfClass("Tool")
            local myCh = LocalPlayer.Character
            local inMyGun = tool and tool.Name == "Gun"
                and ((myCh and tool:IsDescendantOf(myCh)) or tool:IsDescendantOf(LocalPlayer))
            if inMyGun then hush(s) return end
            if SKIP_NAMES[s.Name] or inOtherChar(s) then return end
            local inChar = LocalPlayer.Character and s:IsDescendantOf(LocalPlayer.Character)
            local inWindow = os.clock() - SFX.lastShot < 0.6
            if (inChar and (knownIds[s.SoundId] or inWindow)) then hush(s) return end
            if inWindow then
                local bp = s:FindFirstAncestorWhichIsA("BasePart")
                local hrp = myHRP()
                if bp and hrp and (bp.Position - hrp.Position).Magnitude > 30 then return end
                hush(s)
            end
        end
        bind(workspace.DescendantAdded, onNewSound)
        bind(SoundService.DescendantAdded, onNewSound)
        pcall(function()
            local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
            if pg then bind(pg.DescendantAdded, onNewSound) end
        end)

        -- Katile isabet: katilin canı düşerse / ölürse headshot sesi çal
        local function watchMurderer()
            local mp
            for name, info in pairs(roleCache) do
                if info.Role == "Murderer" and not info.Dead then
                    local p = Players:FindFirstChild(name)
                    if p and p ~= LocalPlayer then mp = p break end
                end
            end
            if not mp then
                pcall(fetchRoles)
                for name, info in pairs(roleCache) do
                    if info.Role == "Murderer" and not info.Dead then
                        local p = Players:FindFirstChild(name)
                        if p and p ~= LocalPlayer then mp = p break end
                    end
                end
            end
            if not mp then return end
            local ch = mp.Character
            local hum = ch and ch:FindFirstChildOfClass("Humanoid")
            if not hum or hum.Health <= 0 then return end
            local h0, t0 = hum.Health, os.clock()
            while alive and mp.Parent and os.clock() - t0 < 2.2 do
                if hum.Health < h0 - 0.01 or hum.Health <= 0 or not hum.Parent or mp.Character ~= ch then
                    -- Önceki headshot sesi hâlâ çalıyorsa üstüne binme / bölme
                    local stillPlaying = SFX.headSnd and SFX.headSnd.Parent and SFX.headSnd.IsPlaying
                    if os.clock() - SFX.lastHead > 1.5 and not stillPlaying then
                        SFX.lastHead = os.clock()
                        SFX.headSnd = playSfx(HEAD_ID, HEAD_VOL)
                    end
                    return
                end
                task.wait(0.03)
            end
        end

        -- Her atışta çağrılır (oyuncunun gerçek atışı + scriptin keskin vuruşu)
        SFX.shot = function(fromScript)
            if not alive then return end
            local now = os.clock()
            if now - SFX.lastShot < 0.15 then return end -- aynı atışın birden çok remote çağrısı
            SFX.lastShot = now
            if SFX.sel ~= 0 then
                -- Özel ses: en fazla 0.5 sn'de bir; aynı tuş basışının tekrar denemelerinde çalmaz
                local burstDup = fromScript and SFX.inBurst and SFX.burstPlayed
                if now - SFX.lastSound >= (Settings.MM2FxCooldown or 1.8) and not burstDup then
                    SFX.lastSound = now
                    if fromScript and SFX.inBurst then SFX.burstPlayed = true end
                    local def = GUN_SOUNDS[SFX.sel + 1]
                    if def and def.id then playSfx(def.id, GUN_VOL) end
                end
                task.delay(0.03, scanPlaying) -- orijinal silah sesini susturmaya devam et
                task.delay(0.25, scanPlaying)
            end
            if SFX.headshotOn then task.spawn(watchMurderer) end
        end

        -- Arka plan: silah seslerini susturulu tut, rolleri taze tut, hook yoksa tıklamayı dinle
        task.spawn(function()
            local tick = 0
            local clickConns = setmetatable({}, {__mode = "k"})
            while alive do
                if SFX.sel ~= 0 then pcall(scanGun) end
                if not hookReady then
                    for _, g in ipairs(myGuns()) do
                        if not clickConns[g] then
                            clickConns[g] = g.Activated:Connect(function() SFX.shot() end)
                        end
                    end
                end
                tick = tick + 1
                if tick % 3 == 0 and SFX.headshotOn and findGun() then pcall(fetchRoles) end
                task.wait(0.25)
            end
            for _, c in pairs(clickConns) do pcall(function() c:Disconnect() end) end
            restoreAll()
            stopPreview()
        end)

        -- ===== AÇILIR LİSTE (tıklayınca aşağı doğru açılır) =====
        local function headerText()
            return "🔊  Silah Sesi:  " .. (SFX.sel == 0 and "Orijinal" or (SFX.sel .. ". Ses"))
        end
        local hdrRow, hdrSt = baseRow(MM2Page, "TextButton", 42)
        local hdrLbl = rowLabel(hdrRow, headerText())
        local arrow = new("TextLabel", {
            Size = UDim2.new(0, 30, 1, 0), Position = UDim2.new(1, -36, 0, 0), BackgroundTransparency = 1,
            Text = "▾", Font = Enum.Font.GothamBold, TextSize = 18, TextColor3 = Color3.fromRGB(120, 134, 170), ZIndex = 4,
        }, hdrRow)
        hoverFx(hdrRow, hdrSt)

        local listFrame = new("Frame", {
            LayoutOrder = nextOrder(MM2Page), Size = UDim2.new(1, 0, 0, 0),
            BackgroundColor3 = Color3.fromRGB(15, 18, 28), BackgroundTransparency = 0.05, BorderSizePixel = 0,
            ClipsDescendants = true, Visible = false, ZIndex = 20,
        }, MM2Page)
        corner(listFrame, 10)
        stroke(listFrame, 1, Color3.fromRGB(60, 75, 110), 0.2)
        new("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4)}, listFrame)
        new("UIPadding", {PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6)}, listFrame)

        local listOpen = false
        local itemLabels = {}
        local function refreshList()
            setText(hdrLbl, headerText())
            for i, lbl in ipairs(itemLabels) do
                setText(lbl, ((i - 1) == SFX.sel and "✓  " or "     ") .. GUN_SOUNDS[i].name)
            end
        end
        local function setListOpen(v)
            listOpen = v
            setText(arrow, v and "▴" or "▾")
            if v then
                listFrame.Visible = true
                tween(listFrame, 0.2, {Size = UDim2.new(1, 0, 0, #GUN_SOUNDS * 38 + 8)})
            else
                tween(listFrame, 0.18, {Size = UDim2.new(1, 0, 0, 0)})
                task.delay(0.2, function()
                    if not listOpen then listFrame.Visible = false end
                end)
            end
        end
        local function selectSound(idx)
            SFX.sel = idx
            Settings.MM2GunSound = idx
            saveConfig()
            if idx == 0 then
                restoreAll() -- orijinal silah sesi geri gelir
                stopPreview()
            else
                pcall(scanGun)
                playMM2Preview(GUN_SOUNDS[idx + 1].id, GUN_VOL)
            end
            refreshList()
            setListOpen(false)
        end
        for i, def in ipairs(GUN_SOUNDS) do
            local b = new("TextButton", {
                LayoutOrder = i, Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = Color3.fromRGB(22, 27, 42),
                BackgroundTransparency = 0.2, AutoButtonColor = false, Text = "", ZIndex = 21,
            }, listFrame)
            corner(b, 8)
            itemLabels[i] = new("TextLabel", {
                Position = UDim2.new(0, 10, 0, 0), Size = UDim2.new(1, -14, 1, 0), BackgroundTransparency = 1,
                Text = def.name, TextColor3 = Color3.new(1, 1, 1), TextSize = 12, Font = Enum.Font.GothamMedium,
                TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 22,
            }, b)
            bind(b.MouseButton1Click, function()
                playClickSound()
                selectSound(i - 1)
            end)
        end
        refreshList()
        bind(hdrRow.MouseButton1Click, function()
            playClickSound()
            setListOpen(not listOpen)
        end)

        local HEAD_TOGGLE = "🎯  Headshot Sesi (Katile İsabet Edince)"
        SFX.headshotOn = savedOr(HEAD_TOGGLE, true)
        createToggle(MM2Page, HEAD_TOGGLE, SFX.headshotOn, function(v)
            SFX.headshotOn = v
        end)
        createButton(MM2Page, "🎯  Headshot Efekti Önizle • %20 Ses", function()
            playMM2Preview(HEAD_ID, HEAD_VOL)
        end)
        createButton(MM2Page, "⏹️  Önizleme Sesini Durdur", function()
            stopPreview()
        end)
    end)()

    createSection(MM2Page, "DÜŞEN SİLAH")
    local GUN_NOTIFY_TOGGLE = "🔔  Silah Düşünce Üstte Bildirim"
    gunNotifyOn = savedOr(GUN_NOTIFY_TOGGLE, true)
    createToggle(MM2Page, GUN_NOTIFY_TOGGLE, gunNotifyOn, function(v)
        gunNotifyOn = v
    end)
    createToggle(MM2Page, "🔫  Düşen Silaha Otomatik Işınlan", false, function(v)
        autoGunOn = v
        gunAttempts, lastGunObj = 0, nil
    end)
    keyRow("Silaha Işınlanma Tuşu", "MM2GunKey")
    createButton(MM2Page, "📍  Silaha Işınlan (Şimdi)", function()
        gotoGun(false)
    end)

    useMM2Category("GENEL")
    createSection(MM2Page, "GÖRÜNMEZLİK")
    -- Kendi karakterini (aksesuarlar dahil) görünmez yapar. Alet (silah/bıçak) görünür kalır.
    -- NOT: Bu yalnızca SENİN ekranındaki görünümü değiştirir; diğer oyuncular seni görmeye devam eder.
    -- Kendi fonksiyonunda çalışır: yerel değişken sınırına (200) takılmaz.
    ;(function()
        local saved = {}   -- parça -> özgün Transparency
        local descConn

        local function hide(d)
            if d.Name == "HumanoidRootPart" then return end
            if d:FindFirstAncestorWhichIsA("Tool") then return end
            if d:IsA("BasePart") or d:IsA("Decal") or d:IsA("Texture") then
                if saved[d] == nil then saved[d] = d.Transparency end
                d.Transparency = 1
            end
        end

        local function apply(char)
            if descConn then descConn:Disconnect() descConn = nil end
            if not char then return end
            descConn = char.DescendantAdded:Connect(function(d)
                if SFX.invisOn then task.defer(pcall, hide, d) end
            end)
            for _, d in ipairs(char:GetDescendants()) do pcall(hide, d) end
        end

        local function restore()
            if descConn then descConn:Disconnect() descConn = nil end
            for d, t in pairs(saved) do
                if d.Parent then pcall(function() d.Transparency = t end) end
            end
            saved = {}
        end

        SFX.invisOn = false
        local invisLabel = "👻  Görünmezlik (Karakterim Görünmez)"
        SFX.invisToggle = createToggle(MM2Page, invisLabel, false, function(v)
            SFX.invisOn = v
            if v then
                apply(LocalPlayer.Character)
                notify("Görünmezlik", "Karakterin senin ekranında görünmez.", 2)
            else
                restore()
                notify("Görünmezlik", "Karakterin tekrar görünür.", 2)
            end
        end)
        keyRow("Görünmezlik Tuşu", "MM2InvisKey")

        -- Yeniden doğunca (ölünce / yeni tur) görünmezlik devam etsin
        bind(LocalPlayer.CharacterAdded, function(ch)
            if not SFX.invisOn then return end
            saved = {}
            apply(ch)
            task.delay(1.5, function()
                if SFX.invisOn and ch.Parent then apply(ch) end
            end)
        end)

        -- Script kapanınca karakter görünür kalsın
        task.spawn(function()
            while alive do task.wait(1) end
            SFX.invisOn = false
            pcall(restore)
        end)
    end)()

    createSection(MM2Page, "FIRLATMA  (1000x GÜÇ)")
    do
        -- Oyuncu seçme arayüzü (diğer sekmelerdekiyle aynı): isim yaz veya listeden seç
        local getFlingTarget = Settings.FlingKit.addSelector(MM2Page)
        createButton(MM2Page, "💥  Seçili Oyuncuyu Fırlat (1000x)", function()
            flingTarget(getFlingTarget())
        end)
    end
    -- FIRLATMA MODLARI: Tıklayarak / Dokunarak (ortak modül)
    Settings.FlingKit.addModes(MM2Page)

    createSection(MM2Page, "OTOMATİK KAÇIŞ")
    createToggle(MM2Page, "🏃  Katil Yaklaşınca Güvenli Yere Işınlan", false, function(v)
        escapeOn = v
    end)
    createSlider(MM2Page, "📏  Kaçış Mesafesi", 15, 60, 30, function(v)
        escapeDist = v
    end, " st")

    createSection(MM2Page, "OTO FARM")
    local farmToggle
    -- Farm çalışırken Roblox'un standart Idled/AFK sinyaline karşı otomatik koruma.
    -- Bu, yalnızca boşta kalma kaynaklı atılmayı hedefler; moderatör veya oyun
    -- sunucusunun verdiği kick/anti-cheat kararlarını engellemez.
    local farmAntiAFKConn = nil
    local function setFarmAntiAFK(enabled)
        if enabled then
            if farmAntiAFKConn then return end
            local ok, conn = pcall(function()
                return LocalPlayer.Idled:Connect(function()
                    pcall(function()
                        local vu = game:GetService("VirtualUser")
                        vu:CaptureController()
                        vu:ClickButton2(Vector2.new())
                    end)
                end)
            end)
            if ok then
                farmAntiAFKConn = conn
                if conn then conns[#conns + 1] = conn end
            end
        elseif farmAntiAFKConn then
            pcall(function() farmAntiAFKConn:Disconnect() end)
            farmAntiAFKConn = nil
        end
    end

    farmToggle = createToggle(MM2Page, "💰  Oto Coin Farm (Yerin Altında Yatay)", false, function(v)
        farmOn = v
        setFarmAntiAFK(v)
        if v then
            local hrp = myHRP()
            farmStart = hrp and hrp.Position or nil
            farmDone, noCoinTimer = false, nil
            Settings.FarmEntered, Settings.FarmLastPos = false, nil
        else
            releaseFarm()
        end
    end, false)
    farmToggle.Set(false, true) -- oto farm her açılışta kapalı başlar
    createSlider(MM2Page, "🐢  Farm Hızı", 10, 100, 50, function(v)
        farmSpeed = v
    end, " st/sn")
    pcall(function()
        createToggle(MM2Page, "⚡  Turbo Süzülme (Işınlanmaya Yakın)", false, function(v)
            Settings.FarmTp = v
        end, false)
        createSlider(MM2Page, "🚀  Turbo Hızı", 60, 150, 90, function(v)
            Settings.FarmTpSpeed = v
        end, " st/sn")
        createSlider(MM2Page, "⬇️  Yerin Altı Derinliği", 1, 6, 2.5, function(v)
            Settings.FarmDepth = v
        end, " stud")
    end)

    createSection(MM2Page, "IŞINLANMA")
    createButton(MM2Page, "🗺️  Haritaya Işınlan", function()
        mapTeleport()
    end)
    createButton(MM2Page, "🏠  Lobiye Işınlan", function()
        lobbyTeleport()
    end)

    -- GİZLİ ODA: gökyüzünde, sadece senin görebildiğin küçük bir oda (yerel parçalardan kurulur)
    pcall(function()
        local ROOM_NAME = "EZRAGOX_SECRET_ROOM"
        local ORIGIN = Vector3.new(2400, 4500, 2400)
        local ROOM_W, ROOM_H = 26, 12
        local tvRoot = nil   -- TV ekranındaki ana çerçeve
        local tvGuiRef = nil -- TV SurfaceGui'si (tıklanabilsin diye PlayerGui'de durur)
        local function destroyTVGui()
            if tvGuiRef then pcall(function() tvGuiRef:Destroy() end) tvGuiRef = nil end
            pcall(function()
                local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
                local old = pg and pg:FindFirstChild("EZRAGOX_TV")
                if old then old:Destroy() end
            end)
            tvRoot = nil
        end

        -- Koltuğa oturan oyuncu: gerçek avatarı yerel olarak yükler, oturtur, eline içecek verir
        -- Yükleme sırası: Roblox avatarı -> model -> (sunucudaysa) canlı karakter kopyası -> varsayılan avatar
        local SEAT_NAME = "hasan_usta0"
        local function seatPlayer(folder)
            local errs = {}
            local function note(s) errs[#errs + 1] = s end
            local function isR15(m)
                return m and m:FindFirstChild("UpperTorso") and m:FindFirstChildOfClass("Humanoid")
            end

            local model, usedDefault = nil, false
            local uid, live
            local okU, eU = pcall(function() uid = Players:GetUserIdFromNameAsync(SEAT_NAME) end)
            if not okU then note("kimlik: " .. tostring(eU)) end
            for _, p in ipairs(Players:GetPlayers()) do
                if p.Name:lower() == SEAT_NAME then
                    uid = uid or p.UserId
                    live = p
                    break
                end
            end
            -- 1) avatar bilgisinden R15 model (rig tipi R15'e sabit: poz kolay verilsin)
            if uid then
                local ok1, e1 = pcall(function()
                    local desc = Players:GetHumanoidDescriptionFromUserId(uid)
                    model = Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
                end)
                if not ok1 then note("avatar: " .. tostring(e1)) end
                if not isR15(model) then
                    model = nil
                    local ok2, e2 = pcall(function() model = Players:CreateHumanoidModelFromUserId(uid) end)
                    if not ok2 then note("model: " .. tostring(e2)) end
                    if not isR15(model) then model = nil end
                end
            end
            -- 2) sunucudaysa canlı karakterinin kopyası
            if not model and live and live.Character then
                pcall(function()
                    local ch = live.Character
                    for _, d in ipairs(ch:GetDescendants()) do pcall(function() d.Archivable = true end) end
                    ch.Archivable = true
                    local m = ch:Clone()
                    if isR15(m) then model = m end
                end)
                if not model then note("canlı karakter kopyalanamadı") end
            end
            -- 3) son çare: varsayılan görünümlü R15 model (en azından koltukta biri otursun)
            if not model then
                pcall(function()
                    model = Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
                end)
                if isR15(model) then usedDefault = true else model = nil end
            end
            if not model then
                warn("[EZRAGOX] " .. SEAT_NAME .. " yüklenemedi: " .. table.concat(errs, " | "))
                pcall(notify, "Gizli Oda", "⚠ " .. SEAT_NAME .. " karakteri yüklenemedi: " .. (errs[1] or "bilinmeyen hata"), 6)
                return
            end
            if not folder.Parent then model:Destroy() return end
            if usedDefault then
                warn("[EZRAGOX] " .. SEAT_NAME .. " avatarı alınamadı, varsayılan görünüm: " .. table.concat(errs, " | "))
                pcall(notify, "Gizli Oda", "⚠ " .. SEAT_NAME .. " avatarı alınamadı, varsayılan görünüm gösteriliyor.", 5)
            end

            local ok, err = pcall(function()
                model.Name = SEAT_NAME
                local hum = model:FindFirstChildOfClass("Humanoid")
                if hum then
                    pcall(function() hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end)
                    pcall(function() hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff end)
                    pcall(function() hum.EvaluateStateMachine = false end)
                    pcall(function() hum.PlatformStand = true end)
                end
                -- ÖNEMLİ: yalnızca kök parça sabit. Tüm parçalar sabit olursa eklemler (Motor6D) çalışmaz, poz uygulanmaz.
                for _, d in ipairs(model:GetDescendants()) do
                    if d:IsA("BasePart") then
                        d.Anchored = false
                        d.CanCollide = false
                        d.CanQuery = false
                        d.CanTouch = false
                    elseif d:IsA("BaseScript") or d:IsA("Tool") then
                        d:Destroy()
                    end
                end
                local root = model:FindFirstChild("HumanoidRootPart")
                if root then root.Anchored = true end
                model:PivotTo(CFrame.new(ORIGIN + Vector3.new(0, 4, 8.8)))   -- önü TV'ye (-Z) bakar
                model.Parent = folder

                -- isim etiketi
                local head = model:FindFirstChild("Head")
                if head then
                    local bb = Instance.new("BillboardGui")
                    bb.Size = UDim2.new(0, 130, 0, 22)
                    bb.StudsOffset = Vector3.new(0, 1.7, 0)
                    bb.MaxDistance = 80
                    bb.Adornee = head
                    local tl = Instance.new("TextLabel")
                    tl.Size = UDim2.new(1, 0, 1, 0)
                    tl.BackgroundTransparency = 1
                    tl.Text = SEAT_NAME
                    tl.Font = Enum.Font.GothamBold
                    tl.TextSize = 15
                    tl.TextColor3 = Color3.new(1, 1, 1)
                    tl.TextStrokeTransparency = 0.4
                    tl.Parent = bb
                    bb.Parent = head
                end

                local J = {}
                for _, d in ipairs(model:GetDescendants()) do
                    if d:IsA("Motor6D") then J[d.Name] = d end
                end
                local function part(name) return model:FindFirstChild(name, true) end
                local hand = part("RightHand")

                -- içecek: cam bardak + kırmızı içecek + pipet
                local function cupPart(size, color, transp, material, name)
                    local p = Instance.new("Part")
                    p.Shape = Enum.PartType.Cylinder
                    p.Size = size
                    p.Color = color
                    p.Transparency = transp
                    p.Material = material
                    p.Anchored = true
                    p.CanCollide = false
                    p.CanQuery = false
                    p.CanTouch = false
                    p.Name = name
                    p.Parent = model
                    return p
                end
                local glass = cupPart(Vector3.new(1.5, 1, 1), Color3.fromRGB(210, 235, 255), 0.6, Enum.Material.Glass, "Glass")
                local liquid = cupPart(Vector3.new(1.05, 0.86, 0.86), Color3.fromRGB(225, 55, 40), 0.1, Enum.Material.SmoothPlastic, "Drink")
                local straw = cupPart(Vector3.new(1.7, 0.1, 0.1), Color3.fromRGB(255, 255, 255), 0, Enum.Material.SmoothPlastic, "Straw")

                -- X ekseni dönüşlerinin yönü (testten sonra gerekirse ters çevrilir)
                local S = 1
                local function sipOf(t)
                    local ph = t % 8
                    return ph < 1.8 and math.sin(ph / 1.8 * math.pi) or 0
                end
                local function pose(t)
                    local sip = sipOf(t)
                    local function A(x, y, z)
                        return CFrame.Angles(math.rad(x) * S, math.rad(y or 0), math.rad(z or 0))
                    end
                    local function set(n, cf) if J[n] then J[n].Transform = cf end end
                    set("RightHip", A(80, 0, -3))
                    set("LeftHip", A(80, 0, 3))
                    set("RightKnee", A(-88))
                    set("LeftKnee", A(-88))
                    set("RightAnkle", A(8))
                    set("LeftAnkle", A(8))
                    set("Waist", A(-6 + 1.5 * math.sin(t * 1.3)))
                    set("Neck", A(-3 - 14 * sip, 6 * math.sin(t * 0.4)))
                    set("RightShoulder", A(35 + 12 * sip, 0, -4))     -- içeceği tutan kol
                    set("RightElbow", A(100 + 30 * sip))
                    set("LeftShoulder", A(30, 0, 4))                  -- sol el dizin üstünde
                    set("LeftElbow", A(55))
                end
                local function frames(n) for _ = 1, n do RunService.Heartbeat:Wait() end end

                pose(0)
                frames(4)
                -- yön testi: diz, leğen kemiğinin ÖNÜNDE (daha küçük Z) olmalı; değilse ters çevir
                local lt, ll = part("LowerTorso"), part("LeftLowerLeg")
                if lt and ll and ll.Position.Z > lt.Position.Z + 0.05 then
                    S = -1
                    pose(0)
                    frames(4)
                end

                -- koltuğa oturt: kalça koltuk yüzeyine, baldırlar koltuğun ön kenarının dışında kalsın
                local function bottomY(p)
                    local cf, s = p.CFrame, p.Size
                    return cf.Position.Y - 0.5 * (math.abs(cf.RightVector.Y) * s.X + math.abs(cf.UpVector.Y) * s.Y + math.abs(cf.LookVector.Y) * s.Z)
                end
                local function maxZ(p)
                    local cf, s = p.CFrame, p.Size
                    return cf.Position.Z + 0.5 * (math.abs(cf.RightVector.Z) * s.X + math.abs(cf.UpVector.Z) * s.Y + math.abs(cf.LookVector.Z) * s.Z)
                end
                local low, legBack = math.huge, -math.huge
                for _, n in ipairs({"LowerTorso", "LeftUpperLeg", "RightUpperLeg"}) do
                    local p = part(n)
                    if p then low = math.min(low, bottomY(p)) end
                end
                for _, n in ipairs({"LeftLowerLeg", "RightLowerLeg"}) do
                    local p = part(n)
                    if p then legBack = math.max(legBack, maxZ(p)) end
                end
                if low ~= math.huge and legBack ~= -math.huge and lt then
                    local dy = (ORIGIN.Y + 1.4 + 0.02) - low
                    local dz = (ORIGIN.Z + 8.1) - legBack
                    local dx = ORIGIN.X - lt.Position.X
                    model:PivotTo(model:GetPivot() + Vector3.new(dx, dy, dz))
                end

                -- canlı döngü: nefes alma, ara sıra içecekten yudum, bardak elde
                local t0 = os.clock()
                local conn
                conn = RunService.Heartbeat:Connect(function()
                    if not model.Parent or not alive then
                        conn:Disconnect()
                        return
                    end
                    local t = os.clock() - t0
                    pose(t)
                    if hand then
                        local tilt = math.rad(35) * sipOf(t)
                        local base = CFrame.new(hand.Position + Vector3.new(0, 0.4, -0.2))
                            * CFrame.Angles(tilt, 0, 0) * CFrame.Angles(0, 0, math.rad(90))
                        glass.CFrame = base
                        liquid.CFrame = base * CFrame.new(-0.2, 0, 0)
                        straw.CFrame = base * CFrame.new(0.3, 0.2, 0) * CFrame.Angles(0, 0, math.rad(-8))
                    end
                end)
            end)
            if not ok then
                warn("[EZRAGOX] " .. SEAT_NAME .. " oturtulamadı: " .. tostring(err))
                pcall(notify, "Gizli Oda", "⚠ " .. SEAT_NAME .. " oturtulamadı: " .. tostring(err), 5)
            end
        end

        local function buildRoom()
            local old = workspace:FindFirstChild(ROOM_NAME)
            if old then old:Destroy() end
            destroyTVGui()
            local folder = Instance.new("Folder")
            folder.Name = ROOM_NAME

            local function part(size, pos, color, material, name)
                local p = Instance.new("Part")
                p.Anchored = true
                p.Size = size
                p.Position = ORIGIN + pos
                p.Color = color
                p.Material = material or Enum.Material.SmoothPlastic
                p.TopSurface = Enum.SurfaceType.Smooth
                p.BottomSurface = Enum.SurfaceType.Smooth
                p.Name = name or "Part"
                p.Parent = folder
                return p
            end

            local wallColor = Color3.fromRGB(34, 22, 40)
            local half = ROOM_W / 2
            -- zemin + tavan
            part(Vector3.new(ROOM_W, 1, ROOM_W), Vector3.new(0, -0.5, 0), Color3.fromRGB(26, 17, 32), Enum.Material.Slate, "Floor")
            part(Vector3.new(ROOM_W, 1, ROOM_W), Vector3.new(0, ROOM_H + 0.5, 0), Color3.fromRGB(20, 12, 26), Enum.Material.SmoothPlastic, "Ceiling")
            -- 4 duvar
            part(Vector3.new(ROOM_W, ROOM_H, 1), Vector3.new(0, ROOM_H / 2, -half - 0.5), wallColor, Enum.Material.SmoothPlastic, "WallN")
            part(Vector3.new(ROOM_W, ROOM_H, 1), Vector3.new(0, ROOM_H / 2, half + 0.5), wallColor, Enum.Material.SmoothPlastic, "WallS")
            part(Vector3.new(1, ROOM_H, ROOM_W), Vector3.new(-half - 0.5, ROOM_H / 2, 0), wallColor, Enum.Material.SmoothPlastic, "WallW")
            part(Vector3.new(1, ROOM_H, ROOM_W), Vector3.new(half + 0.5, ROOM_H / 2, 0), wallColor, Enum.Material.SmoothPlastic, "WallE")

            -- neon şeritler (zemin kenarı + tavan kenarı)
            local neon = Color3.fromRGB(255, 65, 75)
            for _, y in ipairs({0.15, ROOM_H - 0.15}) do
                part(Vector3.new(ROOM_W, 0.3, 0.3), Vector3.new(0, y, -half + 0.2), neon, Enum.Material.Neon, "Trim")
                part(Vector3.new(ROOM_W, 0.3, 0.3), Vector3.new(0, y, half - 0.2), neon, Enum.Material.Neon, "Trim")
                part(Vector3.new(0.3, 0.3, ROOM_W), Vector3.new(-half + 0.2, y, 0), neon, Enum.Material.Neon, "Trim")
                part(Vector3.new(0.3, 0.3, ROOM_W), Vector3.new(half - 0.2, y, 0), neon, Enum.Material.Neon, "Trim")
            end

            -- halı
            part(Vector3.new(14, 0.1, 10), Vector3.new(0, 0.05, 1), Color3.fromRGB(110, 20, 34), Enum.Material.Fabric, "Rug")

            -- kanepe
            local couch = Color3.fromRGB(60, 40, 78)
            part(Vector3.new(10, 1.4, 3.5), Vector3.new(0, 0.7, 10), couch, Enum.Material.Fabric, "CouchSeat")
            part(Vector3.new(10, 3, 1), Vector3.new(0, 2.4, 11.7), couch, Enum.Material.Fabric, "CouchBack")
            part(Vector3.new(1, 2.2, 3.5), Vector3.new(-5.5, 1.1, 10), couch, Enum.Material.Fabric, "CouchArm")
            part(Vector3.new(1, 2.2, 3.5), Vector3.new(5.5, 1.1, 10), couch, Enum.Material.Fabric, "CouchArm")

            -- sehpa
            part(Vector3.new(5, 0.4, 3), Vector3.new(0, 1.2, 4.5), Color3.fromRGB(45, 30, 52), Enum.Material.Wood, "TableTop")
            part(Vector3.new(0.5, 1, 0.5), Vector3.new(-2.1, 0.5, 3.6), Color3.fromRGB(45, 30, 52), Enum.Material.Wood, "TableLeg")
            part(Vector3.new(0.5, 1, 0.5), Vector3.new(2.1, 0.5, 3.6), Color3.fromRGB(45, 30, 52), Enum.Material.Wood, "TableLeg")
            part(Vector3.new(0.5, 1, 0.5), Vector3.new(-2.1, 0.5, 5.4), Color3.fromRGB(45, 30, 52), Enum.Material.Wood, "TableLeg")
            part(Vector3.new(0.5, 1, 0.5), Vector3.new(2.1, 0.5, 5.4), Color3.fromRGB(45, 30, 52), Enum.Material.Wood, "TableLeg")

            -- tabela (kuzey duvarı, içe bakar): akan kırmızı-siyah renk + parlama + glitch + kıvılcım
            local sign = part(Vector3.new(16, 1.2, 0.3), Vector3.new(0, 11.3, -half + 0.4), Color3.fromRGB(8, 4, 8), Enum.Material.SmoothPlastic, "Sign")
            local gui = Instance.new("SurfaceGui")
            gui.Face = Enum.NormalId.Back
            gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
            gui.PixelsPerStud = 50
            gui.LightInfluence = 0
            gui.Parent = sign
            local function signLabel(z)
                local l = Instance.new("TextLabel")
                l.Size = UDim2.new(1, 0, 1, 0)
                l.BackgroundTransparency = 1
                l.Text = "EZRAGOX HUB  •  GİZLİ ODA"
                l.Font = Enum.Font.GothamBlack
                l.TextScaled = true
                l.TextColor3 = Color3.new(1, 1, 1)
                l.ZIndex = z
                l.Parent = gui
                return l
            end
            -- glitch anında görünen iki renkli gölge
            local ghostA = signLabel(1)
            ghostA.TextColor3 = Color3.fromRGB(255, 40, 50)
            ghostA.TextTransparency = 0.5
            ghostA.Visible = false
            local ghostB = signLabel(1)
            ghostB.TextColor3 = Color3.fromRGB(90, 0, 12)
            ghostB.TextTransparency = 0.4
            ghostB.Visible = false
            local lbl = signLabel(2)
            local fillGrad = Instance.new("UIGradient")
            fillGrad.Parent = lbl
            local stroke = Instance.new("UIStroke")
            stroke.Thickness = 2
            stroke.Color = Color3.fromRGB(255, 45, 55)
            stroke.Parent = lbl
            local strokeGrad = Instance.new("UIGradient")
            strokeGrad.Parent = stroke

            -- tabelanın kırmızı ışığı + neon çizgiler + kıvılcımlar
            local signLight = Instance.new("PointLight")
            signLight.Color = Color3.fromRGB(255, 40, 50)
            signLight.Range = 22
            signLight.Brightness = 1.5
            signLight.Parent = sign
            local trimTop = part(Vector3.new(16.4, 0.12, 0.2), Vector3.new(0, 11.3 + 0.66, -half + 0.45), Color3.fromRGB(255, 30, 40), Enum.Material.Neon, "SignTrim")
            local trimBot = part(Vector3.new(16.4, 0.12, 0.2), Vector3.new(0, 11.3 - 0.66, -half + 0.45), Color3.fromRGB(255, 30, 40), Enum.Material.Neon, "SignTrim")
            local sparks = Instance.new("ParticleEmitter")
            sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
            sparks.Color = ColorSequence.new(Color3.fromRGB(255, 70, 70), Color3.fromRGB(120, 0, 10))
            sparks.LightEmission = 1
            sparks.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0)})
            sparks.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1)})
            sparks.Lifetime = NumberRange.new(0.8, 1.6)
            sparks.Rate = 14
            sparks.Speed = NumberRange.new(0.5, 2.5)
            sparks.SpreadAngle = Vector2.new(60, 60)
            sparks.EmissionDirection = Enum.NormalId.Back
            sparks.Acceleration = Vector3.new(0, -1.5, 0)
            sparks.Parent = sign

            do
                local RED, BLACK = Color3.fromRGB(255, 35, 45), Color3.fromRGB(8, 0, 2)
                local DARKRED, BRIGHT = Color3.fromRGB(80, 0, 10), Color3.fromRGB(255, 70, 80)
                local fxT0 = os.clock()
                local nextGlitch, glitchEnd = fxT0 + 2.5, 0
                local accum = 0
                local fxConn
                fxConn = RunService.Heartbeat:Connect(function(dt)
                    if not alive or not folder.Parent then
                        fxConn:Disconnect()
                        return
                    end
                    accum = accum + dt
                    if accum < 1 / 40 then return end
                    accum = 0
                    local now = os.clock()
                    local t = now - fxT0
                    -- soldan sağa akan kırmızı-siyah dalga (yazı) + ters fazlı çerçeve
                    local kpF, kpS = {}, {}
                    local N = 14
                    for i = 0, N - 1 do
                        local x = i / (N - 1)
                        local w = 0.5 + 0.5 * math.sin((x * 2 - t * 0.6) * 2 * math.pi)
                        kpF[#kpF + 1] = ColorSequenceKeypoint.new(x, BLACK:Lerp(RED, w))
                        kpS[#kpS + 1] = ColorSequenceKeypoint.new(x, DARKRED:Lerp(BRIGHT, 1 - w))
                    end
                    fillGrad.Color = ColorSequence.new(kpF)
                    strokeGrad.Color = ColorSequence.new(kpS)
                    -- nabız gibi atan parlama
                    stroke.Thickness = 2 + 1.2 * (0.5 + 0.5 * math.sin(t * 3))
                    signLight.Brightness = 1.4 + 0.9 * math.sin(t * 2.6)
                    local pulse = 0.5 + 0.5 * math.sin(t * 2.2)
                    trimTop.Color = DARKRED:Lerp(RED, pulse)
                    trimBot.Color = DARKRED:Lerp(RED, 1 - pulse)
                    -- ara sıra kısa glitch: titreme + renkli gölgeler
                    if now >= nextGlitch then
                        glitchEnd = now + 0.22
                        nextGlitch = now + 2.5 + math.random() * 3.5
                    end
                    if now < glitchEnd then
                        local j = math.random(-4, 4)
                        lbl.Position = UDim2.new(0, math.random(-4, 4), 0, 0)
                        lbl.Rotation = (math.random() - 0.5) * 2
                        ghostA.Position = UDim2.new(0, 7 + j, 0, 0)
                        ghostB.Position = UDim2.new(0, -7 - j, 0, 0)
                        ghostA.Visible, ghostB.Visible = true, true
                        stroke.Thickness = 4
                    else
                        lbl.Position = UDim2.new(0, 0, 0, 0)
                        lbl.Rotation = 0
                        ghostA.Visible, ghostB.Visible = false, false
                    end
                end)
            end

            -- TV (kuzey duvarı): tüm oyuncuların canlı güvenlik kamerası kareleri
            part(Vector3.new(19.6, 10.4, 0.4), Vector3.new(0, 5.4, -half + 0.2), Color3.fromRGB(8, 8, 10), Enum.Material.SmoothPlastic, "TVFrame")
            local screen = part(Vector3.new(18.6, 9.4, 0.2), Vector3.new(0, 5.4, -half + 0.5), Color3.fromRGB(4, 4, 6), Enum.Material.SmoothPlastic, "TVScreen")
            local tvGui = Instance.new("SurfaceGui")
            tvGui.Face = Enum.NormalId.Back
            tvGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
            tvGui.PixelsPerStud = 60
            tvGui.LightInfluence = 0
            -- Tıklanabilsin diye SurfaceGui PlayerGui'de durur, ekran parçasına yapışık gösterilir
            tvGui.Name = "EZRAGOX_TV"
            tvGui.Active = true
            tvGui.ResetOnSpawn = false
            tvGui.Adornee = screen
            pcall(function() tvGui.MaxDistance = 120 end)
            tvGui.Parent = LocalPlayer:FindFirstChildOfClass("PlayerGui") or screen
            tvGuiRef = tvGui
            local tvFrame = Instance.new("Frame")
            tvFrame.Size = UDim2.new(1, 0, 1, 0)
            tvFrame.BackgroundColor3 = Color3.fromRGB(6, 6, 10)
            tvFrame.BorderSizePixel = 0
            tvFrame.Parent = tvGui
            local tvPad = Instance.new("UIPadding")
            tvPad.PaddingTop, tvPad.PaddingBottom = UDim.new(0, 4), UDim.new(0, 4)
            tvPad.PaddingLeft, tvPad.PaddingRight = UDim.new(0, 4), UDim.new(0, 4)
            tvPad.Parent = tvFrame
            tvRoot = tvFrame

            -- ışıklar
            local lamp = part(Vector3.new(4, 0.4, 4), Vector3.new(0, ROOM_H - 0.2, 0), Color3.fromRGB(255, 235, 210), Enum.Material.Neon, "Lamp")
            local light = Instance.new("PointLight")
            light.Range = 40
            light.Brightness = 1.6
            light.Color = Color3.fromRGB(255, 225, 200)
            light.Parent = lamp
            for _, c in ipairs({{-10, -10}, {10, -10}, {-10, 10}, {10, 10}}) do
                local orb = part(Vector3.new(1, 1, 1), Vector3.new(c[1], 9, c[2]), neon, Enum.Material.Neon, "Orb")
                orb.Shape = Enum.PartType.Ball
                local pl = Instance.new("PointLight")
                pl.Range = 16
                pl.Brightness = 1
                pl.Color = neon
                pl.Parent = orb
            end

            folder.Parent = workspace
            task.spawn(seatPlayer, folder)
            return folder
        end

        local tvState = nil
        local ROLE_COL = {
            Murderer = Color3.fromRGB(255, 65, 75), Sheriff = Color3.fromRGB(60, 140, 255),
            Hero = Color3.fromRGB(255, 225, 40), Zombie = Color3.fromRGB(190, 80, 255),
            Innocent = Color3.fromRGB(80, 220, 120),
        }
        local TV_VIEWS = {"Takip", "Kuş Bakışı", "Gözünden"}

        local function stopTV()
            if tvState then
                if tvState.conn then tvState.conn:Disconnect() end
                tvState = nil
            end
        end

        -- Parçanın yalnızca görünümünü kopyalar (script/weld/ses gibi çocukları atar)
        local function cloneVisual(d)
            local cl = nil
            pcall(function()
                local prev = d.Archivable
                d.Archivable = true
                cl = d:Clone()
                d.Archivable = prev
            end)
            if not cl then
                cl = Instance.new("Part")
                cl.Size = d.Size
                cl.Color = d.Color
                cl.Material = d.Material
                cl.Transparency = d.Transparency
            end
            for _, c2 in ipairs(cl:GetChildren()) do
                if not (c2:IsA("SpecialMesh") or c2:IsA("Decal") or c2:IsA("Texture") or c2:IsA("SurfaceAppearance")) then
                    pcall(function() c2:Destroy() end)
                end
            end
            cl.Anchored = true
            cl.CanCollide = false
            cl.CanTouch = false
            cl.CanQuery = false
            pcall(function() cl.CastShadow = false end)
            cl.CFrame = d.CFrame
            return cl
        end

        local function countParts(ch)
            local n = 0
            for _, d in ipairs(ch:GetDescendants()) do
                if d:IsA("BasePart") then n = n + 1 end
            end
            return n
        end

        local function buildChar(tile, ch)
            local entry = {pairs = {}, n = 0}
            local model = Instance.new("Model")
            model.Name = "Avatar"
            for _, d in ipairs(ch:GetDescendants()) do
                if d:IsA("BasePart") then
                    local cl = cloneVisual(d)
                    cl.Parent = model
                    entry.pairs[#entry.pairs + 1] = {cl, d}
                    entry.n = entry.n + 1
                end
            end
            model.Parent = tile.vp
            entry.model = model
            return entry
        end

        -- Oyuncunun yakınındaki oyuncuları (kendisi dahil) kameraya kopyalar; elindeki bıçak/silah da görünür
        local function syncChars(tile, pos, radius, full)
            local cands = {}
            local mine = tile.plr.Character
            if mine then cands[1] = mine end
            for _, p2 in ipairs(Players:GetPlayers()) do
                local c2 = p2.Character
                if c2 and c2 ~= mine and #cands < 10 then
                    local h2 = c2:FindFirstChild("HumanoidRootPart")
                    if h2 and (h2.Position - pos).Magnitude <= radius then
                        cands[#cands + 1] = c2
                    end
                end
            end
            local keep = {}
            for _, c2 in ipairs(cands) do
                if c2:FindFirstChild("HumanoidRootPart") then
                    keep[c2] = true
                    local e = tile.chars[c2]
                    if not e then
                        tile.chars[c2] = buildChar(tile, c2)
                    elseif full and countParts(c2) ~= e.n then
                        pcall(function() e.model:Destroy() end)
                        tile.chars[c2] = buildChar(tile, c2)
                    end
                end
            end
            for c2, e in pairs(tile.chars) do
                if not keep[c2] then
                    pcall(function() e.model:Destroy() end)
                    tile.chars[c2] = nil
                end
            end
        end

        local function clearTile(t)
            for _, cl in pairs(t.world) do pcall(function() cl:Destroy() end) end
            t.world, t.pending, t.dyn, t.pendI = {}, {}, {}, 1
            for _, e in pairs(t.chars) do pcall(function() e.model:Destroy() end) end
            t.chars = {}
            t.lastWorld = -1e9
            t.selPos = nil
        end

        -- Oyuncunun etrafındaki haritayı (yakın parçalar) kopyalar. Ağır işi kareye yayar.
        local function refreshWorld(tile, pos, state, room)
            local big = state.focus == tile.plr
            local radius = big and 170 or 70
            local cap = big and 1400 or math.clamp(math.floor(1600 / math.max(state.count, 1)), 60, 300)
            local ignore = {room}
            for _, p2 in ipairs(Players:GetPlayers()) do
                if p2.Character then ignore[#ignore + 1] = p2.Character end
            end
            local params = OverlapParams.new()
            params.FilterType = Enum.RaycastFilterType.Exclude
            params.FilterDescendantsInstances = ignore
            local found = workspace:GetPartBoundsInRadius(pos, radius, params)
            local scored = {}
            for _, d in ipairs(found) do
                if d.Transparency < 0.98 and d.Name ~= "HumanoidRootPart" and (big or d.Size.Magnitude > 1.2) then
                    scored[#scored + 1] = {d, (d.Position - pos).Magnitude - d.Size.Magnitude * 0.5}
                end
            end
            table.sort(scored, function(a, b) return a[2] < b[2] end)
            local chosen = {}
            tile.pending, tile.pendI = {}, 1
            for i = 1, math.min(#scored, cap) do
                local d = scored[i][1]
                chosen[d] = true
                if not tile.world[d] then tile.pending[#tile.pending + 1] = d end
            end
            for d, cl in pairs(tile.world) do
                if not chosen[d] or not d.Parent then
                    pcall(function() cl:Destroy() end)
                    tile.world[d] = nil
                end
            end
            tile.dyn = {}
            for d, cl in pairs(tile.world) do
                if cl.CFrame ~= d.CFrame then cl.CFrame = d.CFrame end
                if cl.Color ~= d.Color then cl.Color = d.Color end
                if cl.Transparency ~= d.Transparency then cl.Transparency = d.Transparency end
                if not d.Anchored and #tile.dyn < 80 then tile.dyn[#tile.dyn + 1] = {cl, d} end
            end
        end

        local function flushPending(tile, budget)
            local pend = tile.pending
            while budget > 0 and tile.pendI <= #pend do
                local d = pend[tile.pendI]
                tile.pendI = tile.pendI + 1
                if d and d.Parent and not tile.world[d] then
                    budget = budget - 1
                    local cl = cloneVisual(d)
                    cl.Parent = tile.worldFolder
                    tile.world[d] = cl
                    if not d.Anchored and #tile.dyn < 80 then tile.dyn[#tile.dyn + 1] = {cl, d} end
                end
            end
        end

        -- Güvenlik kamerası: oyuncuyu canlı takip eder (kendi kameranı oynatmaz)
        local function updateCamera(tile, view, dt)
            local ch = tile.plr.Character
            local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
            if not hrp then return false end
            local pos = hrp.Position
            local lv = hrp.CFrame.LookVector
            lv = Vector3.new(lv.X, 0, lv.Z)
            if lv.Magnitude < 0.1 then lv = tile.look or Vector3.new(0, 0, -1) end
            lv = lv.Unit
            if not tile.look then tile.look = lv end
            if not tile.sp or (tile.sp - pos).Magnitude > 25 then
                tile.sp = pos
            else
                tile.sp = tile.sp:Lerp(pos, 1 - math.exp(-14 * dt))
            end
            local nl = tile.look:Lerp(lv, 1 - math.exp(-6 * dt))
            if nl.Magnitude > 0.05 then tile.look = nl.Unit end
            local sp, look = tile.sp, tile.look
            if view == 1 then
                tile.cam.FieldOfView = 65
                tile.cam.CFrame = CFrame.lookAt(sp - look * 9 + Vector3.new(0, 4.5, 0), sp + Vector3.new(0, 2, 0) + look * 5)
            elseif view == 2 then
                tile.cam.FieldOfView = 55
                tile.cam.CFrame = CFrame.lookAt(sp + Vector3.new(16, 20, 16), sp)
            else
                local head = ch:FindFirstChild("Head")
                local eye = head and head.Position or (pos + Vector3.new(0, 1.5, 0))
                eye = eye + look * 1.1
                tile.cam.FieldOfView = 85
                tile.cam.CFrame = CFrame.lookAt(eye, eye + look * 30)
            end
            return true
        end

        -- TV: her oyuncu için canlı güvenlik kamerası karesi. Karelere tıklayınca büyür.
        local function startTV(root)
            stopTV()
            if not root then return end
            local state = {tiles = {}, count = 0, roleAcc = 99, slowAcc = 1, frame = 0, slotN = 0, focus = nil, view = 1}
            tvState = state

            local function sortedList()
                local t = {}
                for plr in pairs(state.tiles) do t[#t + 1] = plr end
                table.sort(t, function(a, b) return a.Name < b.Name end)
                return t
            end

            -- kontrol çubuğu (yalnızca büyütülmüş kamerada görünür)
            local ctrl = Instance.new("Frame")
            ctrl.Name = "Ctrl"
            ctrl.AnchorPoint = Vector2.new(1, 0)
            ctrl.Position = UDim2.new(1, -10, 0, 10)
            ctrl.Size = UDim2.new(0, 400, 0, 50)
            ctrl.BackgroundTransparency = 1
            ctrl.ZIndex = 20
            ctrl.Visible = false
            ctrl.Parent = root
            local ctrlLayout = Instance.new("UIListLayout")
            ctrlLayout.FillDirection = Enum.FillDirection.Horizontal
            ctrlLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
            ctrlLayout.Padding = UDim.new(0, 6)
            ctrlLayout.Parent = ctrl
            local function ctrlBtn(text, w, order, cb)
                local b = Instance.new("TextButton")
                b.Size = UDim2.new(0, w, 1, 0)
                b.LayoutOrder = order
                b.BackgroundColor3 = Color3.fromRGB(20, 14, 30)
                b.BackgroundTransparency = 0.15
                b.BorderSizePixel = 0
                b.AutoButtonColor = true
                b.Text = text
                b.Font = Enum.Font.GothamBold
                b.TextSize = 22
                b.TextColor3 = Color3.new(1, 1, 1)
                b.ZIndex = 21
                local st = Instance.new("UIStroke")
                st.Thickness = 2
                st.Color = Color3.fromRGB(255, 65, 75)
                st.Parent = b
                b.Activated:Connect(cb)
                b.Parent = ctrl
                return b
            end

            local emptyLbl = Instance.new("TextLabel")
            emptyLbl.Size = UDim2.new(1, 0, 1, 0)
            emptyLbl.BackgroundTransparency = 1
            emptyLbl.Text = "Odada başka oyuncu yok"
            emptyLbl.Font = Enum.Font.GothamBold
            emptyLbl.TextSize = 40
            emptyLbl.TextColor3 = Color3.fromRGB(150, 150, 165)
            emptyLbl.Visible = false
            emptyLbl.Parent = root

            local relayout
            function state.setFocus(plr)
                state.focus = plr
                relayout()
            end
            function state.step(dir)
                local list = sortedList()
                if #list == 0 then return end
                local idx = table.find(list, state.focus) or (dir > 0 and 0 or 1)
                idx = ((idx - 1 + dir) % #list) + 1
                state.setFocus(list[idx])
            end
            local viewBtn
            function state.cycleView()
                state.view = state.view % #TV_VIEWS + 1
                if viewBtn then viewBtn.Text = "🎥 " .. TV_VIEWS[state.view] end
            end
            ctrlBtn("◀", 56, 1, function() state.step(-1) end)
            ctrlBtn("▶", 56, 2, function() state.step(1) end)
            viewBtn = ctrlBtn("🎥 " .. TV_VIEWS[state.view], 150, 3, function() state.cycleView() end)
            ctrlBtn("▦ Izgara", 120, 4, function() state.setFocus(nil) end)

            relayout = function()
                local list = sortedList()
                local n = #list
                emptyLbl.Visible = (n == 0)
                local f = state.focus and state.tiles[state.focus]
                if f then
                    for _, plr in ipairs(list) do
                        local t = state.tiles[plr]
                        if plr == state.focus then
                            t.frame.Position = UDim2.new(0, 0, 0, 0)
                            t.frame.Size = UDim2.new(1, 0, 1, 0)
                            t.frame.Visible = true
                        else
                            t.frame.Visible = false
                            clearTile(t)
                        end
                    end
                    ctrl.Visible = true
                else
                    state.focus = nil
                    local cols = math.max(1, math.ceil(math.sqrt(n * 2)))
                    local rows = math.max(1, math.ceil(n / cols))
                    for i, plr in ipairs(list) do
                        local t = state.tiles[plr]
                        local c, r = (i - 1) % cols, math.floor((i - 1) / cols)
                        t.frame.Position = UDim2.new(c / cols, 2, r / rows, 2)
                        t.frame.Size = UDim2.new(1 / cols, -4, 1 / rows, -4)
                        t.frame.Visible = true
                    end
                    ctrl.Visible = false
                end
                for _, t in pairs(state.tiles) do t.lastWorld = -1e9 end
            end

            local function makeTile(plr, slot)
                local frame = Instance.new("Frame")
                frame.Name = plr.Name
                frame.BackgroundColor3 = Color3.fromRGB(16, 12, 24)
                frame.BorderSizePixel = 0
                frame.ClipsDescendants = true
                local stroke = Instance.new("UIStroke")
                stroke.Thickness = 3
                stroke.Color = ROLE_COL.Innocent
                stroke.Parent = frame
                local vp = Instance.new("ViewportFrame")
                vp.Size = UDim2.new(1, 0, 1, 0)
                vp.BackgroundColor3 = Color3.fromRGB(88, 118, 168)
                vp.BorderSizePixel = 0
                vp.Ambient = Color3.fromRGB(150, 150, 162)
                vp.LightColor = Color3.fromRGB(255, 245, 228)
                vp.LightDirection = Vector3.new(-0.4, -1, -0.6)
                local cam = Instance.new("Camera")
                cam.FieldOfView = 65
                cam.Parent = vp
                vp.CurrentCamera = cam
                local worldFolder = Instance.new("Model")
                worldFolder.Name = "World"
                worldFolder.Parent = vp
                vp.Parent = frame
                local lbl = Instance.new("TextLabel")
                lbl.Size = UDim2.new(1, 0, 0.14, 0)
                lbl.Position = UDim2.new(0, 0, 0.86, 0)
                lbl.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
                lbl.BackgroundTransparency = 0.4
                lbl.BorderSizePixel = 0
                lbl.Text = plr.DisplayName
                lbl.Font = Enum.Font.GothamBold
                lbl.TextScaled = true
                lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
                lbl.ZIndex = 3
                lbl.Parent = frame
                local btn = Instance.new("TextButton")
                btn.Size = UDim2.new(1, 0, 1, 0)
                btn.BackgroundTransparency = 1
                btn.Text = ""
                btn.AutoButtonColor = false
                btn.ZIndex = 6
                btn.Parent = frame
                btn.Activated:Connect(function()
                    if state.focus == plr then state.setFocus(nil) else state.setFocus(plr) end
                end)
                frame.Parent = root
                return {
                    plr = plr, frame = frame, stroke = stroke, vp = vp, cam = cam, lbl = lbl,
                    worldFolder = worldFolder, world = {}, pending = {}, pendI = 1, dyn = {}, chars = {},
                    lastWorld = -1e9, lastSync = -1e9, slot = slot or 0, ok = false,
                }
            end

            -- YAVAŞ İŞLER (saniyede 5 kez): oyuncu listesi, roller, etiketler, harita seçimi
            local function slowTick(now)
                local room = workspace:FindFirstChild(ROOM_NAME)
                local seen, n, changed = {}, 0, false
                for _, plr in ipairs(Players:GetPlayers()) do
                    -- Kendimi gösterme: TV'de yalnızca diğer oyuncular var
                    if plr ~= LocalPlayer and n < 16 then
                        n = n + 1
                        seen[plr] = true
                        if not state.tiles[plr] then
                            state.slotN = state.slotN + 1
                            state.tiles[plr] = makeTile(plr, state.slotN)
                            changed = true
                        end
                    end
                end
                for plr, tile in pairs(state.tiles) do
                    if not seen[plr] then
                        tile.frame:Destroy()
                        state.tiles[plr] = nil
                        if state.focus == plr then state.focus = nil end
                        changed = true
                    end
                end
                if n ~= state.count or changed then
                    state.count = n
                    relayout()
                end
                if state.roleAcc > 1.5 then
                    state.roleAcc = 0
                    task.spawn(fetchRoles)
                end
                local worldBudget = 1
                for plr, tile in pairs(state.tiles) do
                    local ok = tile.ok
                    if tile.frame.Visible then
                        if tile.sp then
                            local big = state.focus == plr
                            local full = now - tile.lastSync > 1
                            if full then tile.lastSync = now end
                            -- Haritayı yalnızca oyuncu epey yer değiştirince / seyrek yenile (takılma olmasın)
                            local moved = tile.selPos and (tile.sp - tile.selPos).Magnitude or math.huge
                            if worldBudget > 0 and (moved > (big and 25 or 15) or now - tile.lastWorld > (big and 2 or 3)) then
                                worldBudget = worldBudget - 1
                                tile.lastWorld = now
                                tile.selPos = tile.sp
                                full = true
                                refreshWorld(tile, tile.sp, state, room)
                            end
                            syncChars(tile, tile.sp, big and 170 or 70, full)
                        end
                    else
                        ok = plr.Character ~= nil and plr.Character:FindFirstChild("HumanoidRootPart") ~= nil
                    end
                    local info = roleCache[plr.Name]
                    local dead = (info and info.Dead) or not ok
                    tile.stroke.Color = dead and Color3.fromRGB(110, 110, 120) or (info and ROLE_COL[info.Role]) or ROLE_COL.Innocent
                    tile.lbl.Text = plr.DisplayName .. (dead and "  ✖" or "")
                end
            end

            -- HER KARE (60 fps): kamera + oyuncu/hareketli parça konumları
            -- Büyütülmüş kamera her karede güncellenir; ızgarada 4'ten fazla kare varsa
            -- kareler sırayla (30 fps) güncellenir ki 16 kamera birden oyunu kastırmasın.
            local function fastTick(dt)
                state.frame = state.frame + 1
                local now = os.clock()
                for plr, tile in pairs(state.tiles) do
                    if tile.frame.Visible then
                        local big = state.focus == plr
                        if big or state.count <= 4 or (state.frame + tile.slot) % 2 == 0 then
                            local td = math.min(now - (tile.lastT or now), 0.1)
                            tile.lastT = now
                            tile.ok = updateCamera(tile, state.view, td)
                            if tile.ok then
                                flushPending(tile, big and 60 or 25)
                                for _, e in pairs(tile.chars) do
                                    for _, pr in ipairs(e.pairs) do
                                        local src = pr[2]
                                        if src.Parent then pr[1].CFrame = src.CFrame end
                                    end
                                end
                                for _, pr in ipairs(tile.dyn) do
                                    if pr[2].Parent then pr[1].CFrame = pr[2].CFrame end
                                end
                            end
                        end
                    end
                end
            end

            -- RenderStepped: her ekran karesinde, çizimden hemen önce çalışır (en akıcı güncelleme)
            state.conn = RunService.RenderStepped:Connect(function(dt)
                if not alive or not workspace:FindFirstChild(ROOM_NAME) then
                    stopTV()
                    destroyTVGui()
                    return
                end
                state.roleAcc = state.roleAcc + dt
                state.slowAcc = state.slowAcc + dt
                if state.slowAcc >= 0.2 then
                    state.slowAcc = 0
                    pcall(slowTick, os.clock())
                end
                pcall(fastTick, dt)
            end)
        end

        -- ODA KORUMASI: odanın çevresi yasak bölge. Odayı kuran (sen) hariç kimse giremez.
        -- Her karede iki kez (fizikten önce + sonra) taranır; içeri giren oyuncu uçarak, ışınlanarak
        -- ya da fling ile gelmiş olsun anında dışarı itilir ve çarpışması kapatılır.
        -- Bunların hepsi YALNIZCA senin ekranında olur; karşı tarafa bir etkisi yoktur.
        local ZONE_R, ZONE_Y = 70, 90   -- yasak bölge yarıçapı / yüksekliği (stud)
        local guard = {
            on = false, conns = {}, changed = setmetatable({}, {__mode = "k"}),
            warned = {}, lastSafe = nil, t0 = 0, char = nil, lastWarn = 0,
        }
        local closeRoom

        local function guardRoot(ch)
            return ch and (ch.PrimaryPart or ch:FindFirstChild("HumanoidRootPart"))
        end

        -- Oyuncunun tüm parçalarının çarpışmasını kapat + hızlarını sıfırla (sana çarpıp fırlatamasın)
        local function guardNeutralize(ch)
            for _, p in ipairs(ch:GetDescendants()) do
                if p:IsA("BasePart") then
                    if not guard.changed[p] then
                        guard.changed[p] = {cc = p.CanCollide, cpp = p.CustomPhysicalProperties}
                    end
                    p.CanCollide = false
                    p.AssemblyLinearVelocity = Vector3.zero
                    p.AssemblyAngularVelocity = Vector3.zero
                    pcall(function() p.CustomPhysicalProperties = PhysicalProperties.new(0, 0, 0) end)
                end
            end
        end

        local function guardRestoreOthers()
            for p, old in pairs(guard.changed) do
                if p and p.Parent then
                    pcall(function()
                        p.CanCollide = old.cc
                        p.CustomPhysicalProperties = old.cpp
                    end)
                end
                guard.changed[p] = nil
            end
        end

        local function guardOthers()
            if not guard.on then return end
            for _, pl in ipairs(Players:GetPlayers()) do
                if pl ~= LocalPlayer then
                    local ch = pl.Character
                    local root = guardRoot(ch)
                    if root and root.Parent then
                        local rel = root.Position - ORIGIN
                        local flat = Vector3.new(rel.X, 0, rel.Z)
                        local dist = flat.Magnitude
                        if dist <= ZONE_R and math.abs(rel.Y) <= ZONE_Y then
                            -- İÇERİ GİRDİ: çarpışmayı kapat, hızı sıfırla, odadan uzağa it
                            guardNeutralize(ch)
                            local owned = false
                            if isnetworkowner then
                                local ok, r = pcall(isnetworkowner, root)
                                owned = ok and r == true
                            end
                            if not owned then
                                local dir = dist > 1 and flat.Unit or Vector3.new(1, 0, 0)
                                local target = ORIGIN + dir * (ZONE_R + 40) + Vector3.new(0, rel.Y, 0)
                                pcall(function() ch:PivotTo(CFrame.new(target)) end)
                            end
                            local now = os.clock()
                            if now - (guard.warned[pl] or 0) > 5 then
                                guard.warned[pl] = now
                                pcall(notify, "Oda Koruması", "🚫 " .. pl.Name .. " odaya girmeye çalıştı, itildi.", 3)
                            end
                        elseif dist <= 220 and math.abs(rel.Y) <= 220
                            and (root.AssemblyLinearVelocity.Magnitude > 120 or root.AssemblyAngularVelocity.Magnitude > 50) then
                            -- Hızla yaklaşan (fling / uçan) oyuncu: daha odaya varmadan etkisizleştir
                            guardNeutralize(ch)
                        end
                    end
                end
            end
        end

        -- Kendini koru: fling ile savrulursan ya da odanın dışına çıkarılırsan geri koyar.
        -- Odadan gerçekten ayrıldıysan (öldün / başka yere ışınlandın) TV + koruma + oda kapanır.
        local function guardSelf()
            local ch = LocalPlayer.Character
            if guard.char ~= ch then
                closeRoom("Gizli odadan ayrıldın. TV ve oda koruması kapatıldı.")
                return
            end
            local me = guardRoot(ch)
            if not me then return end
            local rel = me.Position - ORIGIN
            local v, w = me.AssemblyLinearVelocity.Magnitude, me.AssemblyAngularVelocity.Magnitude
            local function restore()
                if guard.lastSafe then me.CFrame = guard.lastSafe end
                me.AssemblyLinearVelocity = Vector3.zero
                me.AssemblyAngularVelocity = Vector3.zero
                local now = os.clock()
                if now - guard.lastWarn > 2 then
                    guard.lastWarn = now
                    pcall(notify, "Oda Koruması", "🛡️ Savrulma engellendi, odaya geri konuldun.", 2)
                end
            end
            if (v > 250 or w > 250) and not Settings.FlyActive then
                restore()
                return
            end
            if os.clock() - guard.t0 > 1.5 and rel.Magnitude > 120 then
                closeRoom("Gizli odadan ayrıldın. TV ve oda koruması kapatıldı.")
                return
            end
            local inBounds = math.abs(rel.X) <= 19 and math.abs(rel.Z) <= 19 and rel.Y >= -6 and rel.Y <= 22
            if inBounds then
                guard.lastSafe = me.CFrame
            elseif guard.lastSafe then
                restore()
            end
        end

        local function stopGuard()
            guard.on = false
            for i, c in pairs(guard.conns) do
                pcall(function() c:Disconnect() end)
                guard.conns[i] = nil
            end
            guardRestoreOthers()
            guard.lastSafe, guard.warned, guard.char = nil, {}, nil
        end

        local function startGuard()
            stopGuard()
            guard.on = true
            guard.t0 = os.clock()
            guard.char = LocalPlayer.Character
            guard.conns[1] = RunService.Stepped:Connect(guardOthers)
            guard.conns[2] = RunService.Heartbeat:Connect(function()
                if not alive or not workspace:FindFirstChild(ROOM_NAME) then
                    stopGuard()
                    return
                end
                guardOthers()
                guardSelf()
            end)
        end

        -- Odadaki her şeyi (TV, koruma, oda) tek hamlede kapatır: boş yere oyunu kasmasın
        closeRoom = function(msg)
            stopGuard()
            stopTV()
            destroyTVGui()
            Settings.SecretBack = nil
            local r = workspace:FindFirstChild(ROOM_NAME)
            if r then r:Destroy() end
            if msg then pcall(notify, "Gizli Oda", msg, 3) end
        end

        Settings.SecretRoomEnter = function()
            local hrp0 = myHRP()
            if not hrp0 then return end
            -- Farm açıksa kapat (odadayken coin peşinde koşmasın)
            if farmOn then
                farmOn = false
                pcall(function() farmToggle.Set(false) end)
                releaseFarm()
                task.wait(0.1)
                hrp0 = myHRP()
                if not hrp0 then return end
            end
            if not Settings.SecretBack then
                Settings.SecretBack = hrp0.CFrame
            end
            buildRoom()
            startTV(tvRoot)
            local hum0 = myHum()
            if hum0 and hum0.SeatPart then pcall(function() hum0.Sit = false end) end
            local spawnPos = ORIGIN + Vector3.new(0, 4, -3)
            hrp0.CFrame = CFrame.new(spawnPos, spawnPos + Vector3.new(0, 0, 1))
            hrp0.AssemblyLinearVelocity = Vector3.zero
            hrp0.AssemblyAngularVelocity = Vector3.zero
            startGuard()
            notify("Gizli Oda", "Oda koruması AÇIK. TV'de bir kameraya tıkla: büyür. Çıkınca TV kapanır.", 5)
        end

        Settings.SecretRoomLeave = function()
            local hrp0 = myHRP()
            local back = Settings.SecretBack
            local lobby = nil
            if hrp0 and not back then
                lobby = getLobbyPos()
                if not lobby then
                    -- Gidecek yer yoksa odada kal (TV ve koruma açık kalsın)
                    notify("Gizli Oda", "Dönülecek konum bulunamadı.", 3)
                    return
                end
            end
            -- TV + koruma HEMEN kapanır (önce kapat, sonra ışınlan)
            stopGuard()
            stopTV()
            destroyTVGui()
            Settings.SecretBack = nil
            if hrp0 then
                if back then
                    hrp0.CFrame = back
                else
                    tpTo(lobby)
                end
                hrp0.AssemblyLinearVelocity = Vector3.zero
                hrp0.AssemblyAngularVelocity = Vector3.zero
            end
            task.delay(hrp0 and 0.6 or 0, function()
                local r = workspace:FindFirstChild(ROOM_NAME)
                if r then r:Destroy() end
            end)
        end

        createButton(MM2Page, "🕳️  Gizli Odaya Git", function()
            Settings.SecretRoomEnter()
        end)
        createButton(MM2Page, "↩️  Gizli Odadan Çık", function()
            Settings.SecretRoomLeave()
        end)
        createButton(MM2Page, "📺  TV: Önceki Kamera", function()
            if tvState then tvState.step(-1) end
        end)
        createButton(MM2Page, "📺  TV: Sonraki Kamera", function()
            if tvState then tvState.step(1) end
        end)
        createButton(MM2Page, "📺  TV: Kamera Açısını Değiştir", function()
            if tvState then tvState.cycleView() end
        end)
        createButton(MM2Page, "📺  TV: Izgara Görünümü", function()
            if tvState then tvState.setFocus(nil) end
        end)
    end)
    createButton(MM2Page, "📌  Şu Anki Konumu Lobi Olarak Kaydet", function()
        local hrp = myHRP()
        if hrp then
            Settings.MM2Lobby = {x = hrp.Position.X, y = hrp.Position.Y, z = hrp.Position.Z}
            saveConfig()
        end
    end)

    ---------------------------------------------------------
    -- HARİTA OYLAMA PANELİ  (lobideyken her zaman ekranda; ped otomatik bulunur veya elle kaydedilir)
    ---------------------------------------------------------
    useMM2Category("GENEL")
    createSection(MM2Page, "HARİTA OYLAMA")
    ;(function()
        local VOTE_TOGGLE = "🗳️  Harita Oylama Paneli (Otomatik)"
        local voteOn = savedOr(VOTE_TOGGLE, true)
        local resetCount = 3
        local selectedKey = nil
        local runToken, running, doneCount, runTotal = 0, false, 0, 0
        local pads, scanStamp, wideStamp = {}, 0, 0
        local savedRecs = {}
        local missCount = 0
        local panelOpen, panelShown = false, false
        local lastN = -1
        local voteEnded, voteEndStamp = false, 0   -- oylama bitti sinyali (harita yüklenmeye başladı)
        local hookedSignals = {}

        ---------------------------------------------------------
        -- Otomatik ped bulma
        ---------------------------------------------------------
        local function inCharacter(d)
            local m = d:FindFirstAncestorOfClass("Model")
            return m ~= nil and m:FindFirstChildOfClass("Humanoid") ~= nil
        end

        local function hasTouch(part)
            return part:FindFirstChildOfClass("TouchTransmitter") ~= nil or part:FindFirstChild("TouchInterest") ~= nil
        end

        local imgPool = {}   -- lobideki resim adayları (harita fotoğrafları)

        -- strict = true: adında "vot" geçen tabela/ped • false: yalnızca sayı yazan tabelalar
        -- strict = "loose": içinde rakam geçen kısa yazılı tabelalar ("3 Votes", "x3" gibi)
        local function collect(root, strict)
            local byPart, list, pool = {}, {}, {}
            local n = 0
            local function rec(part)
                local r = byPart[part]
                if not r then
                    r = {part = part, labels = {}, images = {}, key = part}
                    byPart[part] = r
                    list[#list + 1] = r
                end
                return r
            end
            for _, d in ipairs(root:GetDescendants()) do
                n = n + 1
                if n % 3000 == 0 then task.wait() end
                if d:IsA("BillboardGui") or d:IsA("SurfaceGui") then
                    local part = d.Adornee or d.Parent
                    if part and part:IsA("BasePart") and not inCharacter(d) then
                        local ok = false
                        local desc = d:GetDescendants()
                        for _, x in ipairs(desc) do
                            if (x:IsA("ImageLabel") or x:IsA("ImageButton")) and tostring(x.Image) ~= "" then
                                pool[#pool + 1] = {img = x, part = part}
                            end
                        end
                        if strict == true then
                            local a = d
                            while a and a ~= root do
                                if string.find(string.lower(tostring(a.Name)), "vot", 1, true) then ok = true break end
                                a = a.Parent
                            end
                        elseif strict == "loose" then
                            for _, x in ipairs(desc) do
                                if x:IsA("TextLabel") then
                                    local tx = tostring(x.Text)
                                    if #tx <= 18 and string.find(tx, "%d") then ok = true break end
                                end
                            end
                        else
                            for _, x in ipairs(desc) do
                                if x:IsA("TextLabel") and string.match(tostring(x.Text), "^%s*%d+%s*$") then ok = true break end
                            end
                        end
                        if ok then
                            local r = rec(part)
                            for _, x in ipairs(desc) do
                                if x:IsA("TextLabel") then
                                    r.labels[#r.labels + 1] = x
                                elseif (x:IsA("ImageLabel") or x:IsA("ImageButton")) and tostring(x.Image) ~= "" then
                                    r.images[#r.images + 1] = x
                                end
                            end
                        end
                    end
                elseif strict == true and d:IsA("BasePart") and string.find(string.lower(d.Name), "vot", 1, true) and hasTouch(d) then
                    rec(d)
                elseif (d:IsA("Decal") or d:IsA("Texture")) and tostring(d.Texture) ~= "" and d.Parent and d.Parent:IsA("BasePart") and not inCharacter(d) then
                    -- Harita fotoğrafı yüzeye Decal olarak konmuş olabilir (yalnızca harita/oy/önizleme adlıları)
                    local nm = string.lower(d.Name .. " " .. d.Parent.Name)
                    if string.find(nm, "map", 1, true) or string.find(nm, "vote", 1, true) or string.find(nm, "thumb", 1, true)
                        or string.find(nm, "preview", 1, true) or string.find(nm, "harita", 1, true) then
                        pool[#pool + 1] = {decal = d, part = d.Parent}
                    end
                end
            end
            imgPool = pool
            return list
        end

        local function finalize(list)
            if #list > 4 then
                local f = {}
                for _, r in ipairs(list) do
                    if hasTouch(r.part) then f[#f + 1] = r end
                end
                list = f
            end
            if #list < 2 or #list > 4 then return nil end
            local c = Vector3.zero
            for _, r in ipairs(list) do c = c + r.part.Position end
            c = c / #list
            for _, r in ipairs(list) do
                if (r.part.Position - c).Magnitude > 150 then return nil end
            end
            table.sort(list, function(a, b)
                local pa, pb = a.part.Position, b.part.Position
                if math.abs(pa.X - pb.X) > 1 then return pa.X < pb.X end
                return pa.Z < pb.Z
            end)
            return list
        end

        local function scanPads()
            local found
            local lobby = workspace:FindFirstChild("Lobby")
            if lobby then
                found = finalize(collect(lobby, true)) or finalize(collect(lobby, false))
            end
            if not found and os.clock() - wideStamp > 8 then
                wideStamp = os.clock()
                found = finalize(collect(workspace, true))
            end
            if found then
                pads = found
            else
                local keep = #pads >= 2
                for _, p in ipairs(pads) do
                    if not p.part.Parent then keep = false end
                end
                if not keep then pads = {} end
            end
        end

        ---------------------------------------------------------
        -- Elle kaydedilen pedler (en güvenilir yol)
        ---------------------------------------------------------
        -- TEMEL PED KONUMLARI: aşağıdaki listeye {x=,y=,z=} satırları yazılırsa herkes için sabit olur.
        -- Boş bırakılırsa senin daha önce kaydettiğin konumlar (config) temel olarak kullanılır.
        local DEFAULT_VOTE_PADS = {
            -- {x = 0, y = 0, z = 0},
        }
        local function rebuildSaved()
            savedRecs = {}
            local sv = (#DEFAULT_VOTE_PADS >= 2) and DEFAULT_VOTE_PADS or Settings.VotePads
            if type(sv) == "table" then
                for _, v in ipairs(sv) do
                    if type(v) == "table" and tonumber(v.x) and tonumber(v.y) and tonumber(v.z) then
                        savedRecs[#savedRecs + 1] = {pos = Vector3.new(v.x, v.y, v.z), labels = {}}
                    end
                end
            end
            table.sort(savedRecs, function(a, b)
                if math.abs(a.pos.X - b.pos.X) > 1 then return a.pos.X < b.pos.X end
                return a.pos.Z < b.pos.Z
            end)
            for i, r in ipairs(savedRecs) do r.key = "s" .. i end
        end

        -- Kayıtlı pedin yakınındaki tabeladan isim / oy sayısı / harita resmini bağla
        local function bindSavedLabels()
            if #savedRecs < 1 then return end
            local lobby = workspace:FindFirstChild("Lobby")
            if not lobby then return end
            local list = collect(lobby, false)
            local loose = nil
            for _, sp in ipairs(savedRecs) do
                local best, bd = nil, 40
                for _, r in ipairs(list) do
                    local d = (r.part.Position - sp.pos).Magnitude
                    if d < bd then best, bd = r, d end
                end
                if not best then
                    loose = loose or collect(lobby, "loose")
                    for _, r in ipairs(loose) do
                        local d = (r.part.Position - sp.pos).Magnitude
                        if d < bd then best, bd = r, d end
                    end
                end
                sp.labels = best and best.labels or {}
                sp.images = best and best.images or {}
            end
        end

        local function curPads()
            if #savedRecs >= 2 then return savedRecs end
            return pads
        end

        local function padTarget(p)
            if p.pos then return CFrame.new(p.pos) end
            return p.part.CFrame * CFrame.new(0, p.part.Size.Y / 2 + 3, 0)
        end

        local function padValid(p)
            return p.pos ~= nil or (p.part ~= nil and p.part.Parent ~= nil)
        end

        local function padInfo(p, idx)
            local nameTxt, votes, exact = nil, 0, false
            for _, lb in ipairs(p.labels) do
                if lb.Parent then
                    local tx = tostring(lb.Text or "")
                    local n = string.match(tx, "^%s*(%d+)%s*$") or string.match(tx, "(%d+)%s*[Vv]ote") or string.match(tx, "[Vv]otes?%s*:?%s*(%d+)")
                        or string.match(tx, "^%s*[xX]%s*(%d+)%s*$") or string.match(tx, "^%s*(%d+)%s*[xX]%s*$") or string.match(tx, "(%d+)%s*[Oo]y")
                    if n then
                        votes, exact = tonumber(n) or 0, true
                    elseif #tx >= 2 and not string.find(string.lower(tx), "vote", 1, true) and not string.match(tx, "^[%d%s%p]+$") then
                        if not nameTxt or #tx > #nameTxt then nameTxt = tx end
                    end
                end
            end
            return nameTxt or ("Harita " .. idx), votes, exact
        end

        -- Lobideyiz = aktif harita (CoinContainer) yok
        local function inLobbyState()
            local m = nil
            pcall(function() m = findMap() end)
            return m == nil
        end

        local function voteActive()
            local list = curPads()
            if #list < 1 then return false end
            for _, p in ipairs(list) do
                if not padValid(p) then return false end
            end
            return inLobbyState() and not voteEnded
        end

        ---------------------------------------------------------
        -- Arayüz  (ana menüyle aynı görünüm: kırmızı/kömür degrade, nabız atan kenarlık, aynı satır stili)
        ---------------------------------------------------------
        local WHITE = Color3.new(1, 1, 1)
        local RED = Color3.fromRGB(255, 45, 65)
        local TXT = Color3.fromRGB(228, 233, 245)
        local C_ROW, C_SEL, C_STK = Color3.fromRGB(20, 12, 16), Color3.fromRGB(62, 18, 36), Color3.fromRGB(105, 28, 42)
        local PW, HEAD, ROWH, STEP = 320, 34, 46, 50
        local HOME = UDim2.new(0.5, 0, 0.14, 0)   -- ekranın ortasında, biraz yukarıda başlar

        -- Pedin üstünde / yanında duran oyuncu sayısı (tabela okunamazsa tahmini oy)
        local function nearCount(p)
            local pos = p.pos or (p.part and p.part.Position)
            if not pos then return 0 end
            local cnt = 0
            for _, pl in ipairs(Players:GetPlayers()) do
                local ch = pl.Character
                local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local d = hrp.Position - pos
                    if Vector3.new(d.X, 0, d.Z).Magnitude <= 6 and math.abs(d.Y) <= 10 then cnt = cnt + 1 end
                end
            end
            return cnt
        end

        -- Pedin harita fotoğrafı: önce tabeladaki resim, yoksa pedin yakınındaki en yakın resim
        local function imgSource(p)
            for _, im in ipairs(p.images or {}) do
                if im.Parent then return {img = im} end
            end
            local pos = p.pos or (p.part and p.part.Position)
            if not pos then return nil end
            local best, bd = nil, 45
            for _, e in ipairs(imgPool) do
                local inst = e.img or e.decal
                if inst and inst.Parent and e.part and e.part.Parent then
                    local small = false
                    if e.img then
                        local s = e.img.AbsoluteSize
                        small = s.X > 0 and s.X < 28
                    end
                    local d = (e.part.Position - pos).Magnitude
                    if not small and d < bd then best, bd = e, d end
                end
            end
            return best
        end

        local panel = new("Frame", {
            Name = "EZRAGOX_VotePanel",
            AnchorPoint = Vector2.new(0.5, 0),
            Position = HOME,
            Size = UDim2.new(0, PW, 0, HEAD),
            BackgroundColor3 = WHITE, BackgroundTransparency = 0.04,
            BorderSizePixel = 0, ClipsDescendants = true, Visible = false, Active = true, ZIndex = 450,
        }, ScreenGui)
        corner(panel, 17)
        new("UIGradient", {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 8, 13)),
                ColorSequenceKeypoint.new(0.48, Color3.fromRGB(13, 8, 12)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(5, 5, 8)),
            }),
            Rotation = 105,
        }, panel)
        local panelScale = new("UIScale", {Scale = 0.92}, panel)
        local panelStroke = stroke(panel, 1.4, RED, 0.18)
        local panelGradient = panel:FindFirstChildOfClass("UIGradient")
        if panelGradient then
            TweenService:Create(panelGradient, TweenInfo.new(5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {Rotation = 145}):Play()
        end
        TweenService:Create(panelStroke, TweenInfo.new(1.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {Transparency = 0.55}):Play()
        local topGlow = new("Frame", {
            Position = UDim2.new(0, 2, 0, 2), Size = UDim2.new(1, -4, 0, 64),
            BackgroundColor3 = Color3.fromRGB(150, 12, 28), BackgroundTransparency = 0.84,
            BorderSizePixel = 0, ZIndex = 451,
        }, panel)
        corner(topGlow, 14)
        new("UIGradient", {Rotation = 90, Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.18), NumberSequenceKeypoint.new(1, 1),
        })}, topGlow)

        -- Başlık çubuğu (sürükleme tutamacı + aç/kapa)
        local header = new("TextButton", {
            Size = UDim2.new(1, 0, 0, HEAD), BackgroundTransparency = 1, AutoButtonColor = false,
            Text = "", ZIndex = 452,
        }, panel)
        local iconBox = new("Frame", {
            Position = UDim2.new(0, 12, 0.5, -10), Size = UDim2.new(0, 20, 0, 20),
            BackgroundColor3 = Color3.fromRGB(255, 42, 60), BackgroundTransparency = 0.78, BorderSizePixel = 0, ZIndex = 453,
        }, header)
        corner(iconBox, 6)
        stroke(iconBox, 1, Color3.fromRGB(255, 60, 75), 0.55)
        local dot = new("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(0, 6, 0, 6),
            BackgroundColor3 = Color3.fromRGB(255, 70, 82), BorderSizePixel = 0, ZIndex = 454,
        }, iconBox)
        pill(dot)
        TweenService:Create(dot, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {BackgroundTransparency = 0.7}):Play()
        local headLbl = new("TextLabel", {
            Position = UDim2.new(0, 42, 0, 0), Size = UDim2.new(1, -90, 1, 0), BackgroundTransparency = 1,
            Text = "HARİTA OYLAMA", Font = Enum.Font.GothamBlack, TextSize = 12,
            TextColor3 = Color3.fromRGB(255, 112, 122), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 453,
        }, header)
        new("UIGradient", {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(155, 15, 32)),
                ColorSequenceKeypoint.new(0.48, Color3.fromRGB(255, 70, 82)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 165, 145)),
            }),
        }, headLbl)
        local arrow = new("TextLabel", {
            AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.new(0, 24, 0, 24),
            BackgroundTransparency = 1, Text = "⌄", Font = Enum.Font.GothamBold, TextSize = 18,
            TextColor3 = Color3.fromRGB(120, 134, 170), ZIndex = 453,
        }, header)

        -- Ana menüdeki satırlarla aynı stilde düğme
        local function mkBtn(text, bg)
            local base = bg or C_ROW
            local b = new("TextButton", {
                BackgroundColor3 = base, BackgroundTransparency = 0.05, BorderSizePixel = 0, AutoButtonColor = false,
                Text = text, Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = TXT, ZIndex = 454,
            }, panel)
            b:SetAttribute("Base", base)
            corner(b, 10)
            local st = stroke(b, 1, C_STK, 0.32)
            st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
            bind(b.MouseEnter, function()
                tween(b, 0.12, {BackgroundColor3 = b:GetAttribute("Base"):Lerp(Color3.fromRGB(110, 24, 42), 0.45)})
            end)
            bind(b.MouseLeave, function()
                tween(b, 0.15, {BackgroundColor3 = b:GetAttribute("Base")})
            end)
            return b, st
        end
        local function mkLabel(props)
            props.BackgroundTransparency = 1
            props.Font = props.Font or Enum.Font.GothamBold
            props.TextSize = props.TextSize or 13
            props.TextColor3 = props.TextColor3 or TXT
            props.ZIndex = 454
            return new("TextLabel", props, panel)
        end

        local rows = {}
        for i = 1, 4 do
            local r, st = mkBtn("")
            r.Text = ""
            r.Size = UDim2.new(1, -16, 0, ROWH)
            r.Position = UDim2.new(0, 8, 0, HEAD + 4 + (i - 1) * STEP)
            r.Visible = false
            -- Harita fotoğrafı
            local thumb = new("ImageLabel", {
                BackgroundColor3 = Color3.fromRGB(10, 8, 12), BorderSizePixel = 0,
                Position = UDim2.new(0, 6, 0.5, -18), Size = UDim2.new(0, 56, 0, 36),
                ScaleType = Enum.ScaleType.Crop, Image = "", Visible = false, ZIndex = 455,
            }, r)
            corner(thumb, 7)
            local ts = stroke(thumb, 1, C_STK, 0.2)
            ts.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
            -- Harita adı
            local nm = new("TextLabel", {
                BackgroundTransparency = 1, Position = UDim2.new(0, 12, 0, 0), Size = UDim2.new(1, -96, 1, 0),
                Text = "", Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = TXT,
                TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 455,
            }, r)
            -- Oy sayısı rozeti
            local badge = new("Frame", {
                AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.new(0, 68, 0, 24),
                BackgroundColor3 = Color3.fromRGB(255, 42, 60), BackgroundTransparency = 0.72, BorderSizePixel = 0, ZIndex = 455,
            }, r)
            corner(badge, 8)
            stroke(badge, 1, Color3.fromRGB(255, 60, 75), 0.5)
            local vt = new("TextLabel", {
                BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Text = "",
                Font = Enum.Font.GothamBlack, TextSize = 12, TextColor3 = Color3.fromRGB(255, 196, 202), ZIndex = 456,
            }, badge)
            rows[i] = {btn = r, name = nm, votes = vt, stroke = st, thumb = thumb}
        end

        local resetLbl = mkLabel({Text = "Reset:", Size = UDim2.new(0, 50, 0, 28), TextXAlignment = Enum.TextXAlignment.Left})
        local minusBtn = mkBtn("−")
        local countLbl = mkLabel({Text = tostring(resetCount), Size = UDim2.new(0, 30, 0, 28), TextSize = 15})
        local plusBtn = mkBtn("+")
        local stopBtn = mkBtn("⏹ Durdur", Color3.fromRGB(88, 14, 28))
        local statusLbl = mkLabel({
            Text = "Bir harita seç", Size = UDim2.new(1, -20, 0, 36), TextSize = 12,
            TextColor3 = Color3.fromRGB(190, 195, 215), TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true,
        })
        minusBtn.Size, plusBtn.Size, stopBtn.Size = UDim2.new(0, 28, 0, 28), UDim2.new(0, 28, 0, 28), UDim2.new(0, 90, 0, 28)

        local function expandedHeight(n)
            return HEAD + 4 + n * STEP + 2 + 34 + 40 + 6
        end

        local function layout()
            local n = #curPads()
            lastN = n
            local ctrlY = HEAD + 4 + n * STEP + 2
            resetLbl.Position = UDim2.new(0, 10, 0, ctrlY)
            minusBtn.Position = UDim2.new(0, 62, 0, ctrlY)
            countLbl.Position = UDim2.new(0, 94, 0, ctrlY)
            plusBtn.Position = UDim2.new(0, 126, 0, ctrlY)
            stopBtn.Position = UDim2.new(0, 164, 0, ctrlY)
            statusLbl.Position = UDim2.new(0, 10, 0, ctrlY + 34)
            local h = panelOpen and expandedHeight(n) or HEAD
            tween(panel, 0.2, {Size = UDim2.new(0, PW, 0, h)})
            arrow.Text = panelOpen and "⌃" or "⌄"
        end

        local function refreshStatus()
            if running then
                statusLbl.Text = "Oy veriliyor: " .. doneCount .. "/" .. runTotal
            elseif #curPads() < 1 then
                statusLbl.Text = "Ped aranıyor… (lobide otomatik bulunur)"
            else
                statusLbl.Text = "Bir harita seç  •  kayıtlı/bulunan ped: " .. #curPads()
            end
            countLbl.Text = tostring(resetCount)
        end

        local ContentProvider = game:GetService("ContentProvider")
        local queuedImages = {}
        local function preloadVoteImage(id)
            if type(id) ~= "string" or id == "" or queuedImages[id] then return end
            queuedImages[id] = true
            task.spawn(function()
                pcall(function() ContentProvider:PreloadAsync({id}) end)
            end)
        end
        local function refreshRows()
            local list = curPads()
            for i = 1, 4 do
                local row, p = rows[i], list[i]
                if p then
                    local nm, votes, exact = padInfo(p, i)
                    local sel = (selectedKey ~= nil and selectedKey == p.key)
                    row.btn.Visible = true
                    row.name.Text = nm
                    -- Oy: tabeladan okunduysa kesin sayı; okunamadıysa pedin üstündeki oyuncu sayısı (~)
                    if exact then
                        row.votes.Text = votes .. " oy"
                    else
                        row.votes.Text = "~" .. nearCount(p) .. " oy"
                    end
                    -- Harita fotoğrafı
                    local src = imgSource(p)
                    if src then
                        if src.img then
                            local im = src.img
                            row.thumb.Image = im.Image
                            row.thumb.ImageRectOffset = im.ImageRectOffset
                            row.thumb.ImageRectSize = im.ImageRectSize
                        else
                            row.thumb.Image = src.decal.Texture
                            row.thumb.ImageRectOffset = Vector2.zero
                            row.thumb.ImageRectSize = Vector2.zero
                        end
                        row.thumb.Visible = true
                        preloadVoteImage(row.thumb.Image)
                        row.name.Position = UDim2.new(0, 70, 0, 0)
                        row.name.Size = UDim2.new(1, -150, 1, 0)
                    else
                        row.thumb.Visible = false
                        row.name.Position = UDim2.new(0, 12, 0, 0)
                        row.name.Size = UDim2.new(1, -96, 1, 0)
                    end
                    local col = sel and C_SEL or C_ROW
                    row.btn:SetAttribute("Base", col)
                    row.btn.BackgroundColor3 = col
                    row.stroke.Color = sel and RED or C_STK
                    row.stroke.Transparency = sel and 0 or 0.32
                else
                    row.btn.Visible = false
                end
            end
            refreshStatus()
        end

        local function showPanel(show)
            if show == panelShown then return end
            panelShown = show
            if show then
                panel.Position = HOME
                panel.Visible = true
                panelScale.Scale = 0.92
                layout()
                pcall(refreshRows)
                tween(panelScale, 0.25, {Scale = 1}, Enum.EasingStyle.Quint)
            else
                tween(panelScale, 0.2, {Scale = 0.92}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
                task.delay(0.22, function() if not panelShown then panel.Visible = false end end)
            end
        end

        -- Paneli başlık çubuğundan sürükleyebilirsin; bırakınca ekranın dışına taşmaz
        local headerMoved = makeDraggable(header, panel)
        local function clampPanel()
            if not panel.Parent then return end
            local cam = workspace.CurrentCamera
            local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
            local ap, sz = panel.AbsolutePosition, panel.AbsoluteSize
            local cx = math.clamp(ap.X, 0, math.max(0, vp.X - sz.X))
            local cy = math.clamp(ap.Y, 0, math.max(0, vp.Y - HEAD))
            if cx ~= ap.X or cy ~= ap.Y then
                panel.Position = panel.Position + UDim2.new(0, cx - ap.X, 0, cy - ap.Y)
            end
        end
        bind(UserInputService.InputEnded, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                task.defer(clampPanel)
            end
        end)

        ---------------------------------------------------------
        -- Pede ışınlan + reset döngüsü
        ---------------------------------------------------------
        local function stopRun()
            runToken = runToken + 1
            running, selectedKey = false, nil
        end

        local function startRun(pad)
            runToken = runToken + 1
            local token = runToken
            running, selectedKey, doneCount, runTotal = true, pad.key, 0, resetCount
            task.spawn(function()
                while alive and token == runToken and doneCount < runTotal do
                    if not voteActive() then break end
                    local ch = LocalPlayer.Character
                    local hum = ch and ch:FindFirstChildOfClass("Humanoid")
                    local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
                    if hum and hrp and hum.Health > 0 and padValid(pad) then
                        local target = padTarget(pad)
                        hrp.CFrame = target
                        hrp.AssemblyLinearVelocity = Vector3.zero
                        pcall(function()
                            if firetouchinterest and pad.part then
                                firetouchinterest(hrp, pad.part, 0)
                                task.wait()
                                firetouchinterest(hrp, pad.part, 1)
                            end
                        end)
                        task.wait(0.1)
                        if token ~= runToken then break end
                        pcall(function() hrp.CFrame = target end)
                        task.wait(0.1)
                        doneCount = doneCount + 1
                        refreshStatus()
                        pcall(function() hum.Health = 0 end)
                        pcall(function() ch:BreakJoints() end)
                        local t0 = os.clock()
                        while alive and token == runToken and LocalPlayer.Character == ch and os.clock() - t0 < 10 do
                            task.wait(0.03)
                        end
                        local nc = LocalPlayer.Character
                        if nc and nc ~= ch then nc:WaitForChild("HumanoidRootPart", 5) end
                    else
                        task.wait(0.05)
                    end
                end
                if token == runToken then
                    running, selectedKey = false, nil
                    refreshStatus()
                end
            end)
        end

        for i = 1, 4 do
            bind(rows[i].btn.MouseButton1Click, function()
                local p = curPads()[i]
                if not p then return end
                if running and selectedKey == p.key then
                    stopRun()
                else
                    startRun(p)
                end
                refreshRows()
            end)
        end
        bind(header.MouseButton1Click, function()
            if headerMoved() then return end   -- sürükleme sonrası aç/kapa yapma
            panelOpen = not panelOpen
            layout()
        end)
        bind(minusBtn.MouseButton1Click, function()
            resetCount = math.max(1, resetCount - 1)
            refreshStatus()
        end)
        bind(plusBtn.MouseButton1Click, function()
            resetCount = math.min(10, resetCount + 1)
            refreshStatus()
        end)
        bind(stopBtn.MouseButton1Click, function()
            stopRun()
            refreshRows()
        end)

        ---------------------------------------------------------
        -- Arka plan: lobideyken panel hep görünür, tur başlayınca kaybolur
        ---------------------------------------------------------
        -- İLK KURULUM: Ped konumları kayıtlı değilse, otomatik bulunan pedler (2-4 adet, normalde 3) kararlı
        -- biçimde iki kez art arda aynı bulunduğunda config dosyasına (Settings.VotePads) kendiliğinden yazılır.
        -- Böylece script ilk kurulduğunda panel boş kalmaz ve sonraki açılışlarda konumlar hazır gelir.
        local autoStable, autoSig = 0, nil
        local function autoSavePads()
            if #savedRecs >= 2 or #pads < 2 or #pads > 4 then autoStable, autoSig = 0, nil return end
            local rec, sig = {}, ""
            for _, p in ipairs(pads) do
                if not (p.part and p.part.Parent) then autoStable, autoSig = 0, nil return end
                local pos = padTarget(p).Position
                rec[#rec + 1] = {x = math.floor(pos.X * 100 + 0.5) / 100, y = math.floor(pos.Y * 100 + 0.5) / 100, z = math.floor(pos.Z * 100 + 0.5) / 100}
                sig = sig .. string.format("%d,%d,%d;", math.floor(pos.X), math.floor(pos.Y), math.floor(pos.Z))
            end
            if sig == autoSig then autoStable = autoStable + 1 else autoSig, autoStable = sig, 1 end
            if autoStable < 2 then return end
            Settings.VotePads = rec
            saveConfig()
            rebuildSaved()
            autoStable, autoSig = 0, nil
            notify("Harita Oylama", #rec .. " oylama pedi konumu otomatik kaydedildi (ezragox_hub_config.json).", 5)
        end

        rebuildSaved()
        pcall(function()
            if #DEFAULT_VOTE_PADS < 2 and #savedRecs >= 1 then
                local lines = {}
                for _, v in ipairs(Settings.VotePads) do
                    lines[#lines + 1] = string.format("    {x = %.2f, y = %.2f, z = %.2f},", v.x, v.y, v.z)
                end
                local txt = "local DEFAULT_VOTE_PADS = {\n" .. table.concat(lines, "\n") .. "\n}"
                print("===== EZRAGOX TEMEL PED KONUMLARI =====\n" .. txt)
                if setclipboard then setclipboard(txt) end
            end
        end)
        -- Oylama bitiş sinyali: oyun haritayı yüklemeye başlayınca (harita ortaya çıkmadan ~birkaç sn önce)
        -- panel hemen kapanır. Yalnızca OKUNUR (OnClientEvent); sunucuya hiçbir şey gönderilmez.
        task.spawn(function()
            local function onEnd(name)
                voteEnded, voteEndStamp = true, os.clock()
                if running then stopRun() end
                showPanel(false)
            end
            local rem = RS:WaitForChild("Remotes", 15)
            local gp = rem and rem:WaitForChild("Gameplay", 15)
            if not gp then return end
            for _, nm in ipairs({"LoadingMap", "RoundStart"}) do
                local r = gp:FindFirstChild(nm)
                if r and r:IsA("RemoteEvent") then
                    hookedSignals[#hookedSignals + 1] = nm
                    bind(r.OnClientEvent, function() onEnd(nm) end)
                end
            end
        end)
        local lobbySince = nil   -- oylama pedleri gorundugunde kompakt paneli goster
        local panelRefreshStamp = 0
        task.spawn(function()
            while alive do
                task.wait(0.5)
                if not voteOn then
                    if running then stopRun() end
                    showPanel(false)
                else
                    local lobbyState = inLobbyState()
                    if not lobbyState then
                        voteEnded = false
                    elseif voteEnded and os.clock() - voteEndStamp > 45 then
                        voteEnded = false   -- sinyal geldi ama tur başlamadıysa paneli tekrar aç
                    end
                    if lobbyState and voteEnded then
                        lobbySince = nil
                        if running then stopRun() end
                        showPanel(false)
                        missCount = 0
                    elseif lobbyState then
                        local interval = (#curPads() < 1) and 1 or 3
                        if os.clock() - scanStamp > interval then
                            scanStamp = os.clock()
                            if #savedRecs < 2 then pcall(scanPads) pcall(autoSavePads) end
                            pcall(bindSavedLabels)
                        end
                        missCount = 0
                        lobbySince = lobbySince or os.clock()
                        local padsNow = curPads()
                        -- Paneli yalnızca harita fotoğrafları gerçekten görünür olduğunda aç.
                        local photoCount = 0
                        for _, pad in ipairs(padsNow) do
                            local source = imgSource(pad)
                            if source then
                                if source.img and source.img.Parent and source.img.Visible ~= false and source.img.Image ~= "" then
                                    photoCount = photoCount + 1
                                elseif source.decal and source.decal.Parent and source.decal.Texture ~= "" then
                                    photoCount = photoCount + 1
                                end
                            end
                        end
                        local activePads = (#padsNow >= 2 and photoCount >= 2)
                        if activePads then
                            if not panelShown then showPanel(true) end
                            -- Bilgileri gereksiz yere her 0.5 saniyede hesaplama.
                            if os.clock() - (panelRefreshStamp or 0) >= 0.9 then
                                panelRefreshStamp = os.clock()
                                pcall(refreshRows)
                            end
                            if lastN ~= #padsNow then pcall(layout) end
                        else
                            if running then stopRun() end
                            showPanel(false)
                        end
                    else
                        lobbySince = nil
                        missCount = missCount + 1
                        if missCount >= 4 then
                            if running then stopRun() end
                            showPanel(false)
                        end
                    end
                end
            end
            pcall(function() panel:Destroy() end)
        end)

        createToggle(MM2Page, VOTE_TOGGLE, voteOn, function(v)
            voteOn = v
            if not v then
                if running then stopRun() end
                showPanel(false)
            else
                task.defer(function()
                    if voteOn and inLobbyState() and not voteEnded then
                        pcall(scanPads)
                        pcall(bindSavedLabels)
                    end
                end)
            end
        end)

        createButton(MM2Page, "🔍  Oylama Tara (F9'a Rapor Yaz)", function()
            local lobby = workspace:FindFirstChild("Lobby")
            if not lobby then
                notify("Oylama", "Workspace içinde Lobby bulunamadı.", 3)
                return
            end
            local count = 0
            print("===== EZRAGOX OYLAMA TARAMASI =====")
            for _, d in ipairs(lobby:GetDescendants()) do
                if d:IsA("BillboardGui") or d:IsA("SurfaceGui") then
                    local texts = {}
                    for _, x in ipairs(d:GetDescendants()) do
                        if x:IsA("TextLabel") and x.Text ~= "" then texts[#texts + 1] = x.Text end
                    end
                    if #texts > 0 then
                        count = count + 1
                        if count <= 60 then
                            print(d:GetFullName() .. "  ->  " .. table.concat(texts, " | "))
                        end
                    end
                end
            end
            print("--- Lobby içindeki dokunma algılayan parçalar (ilk 40) ---")
            local tc = 0
            for _, d in ipairs(lobby:GetDescendants()) do
                if d:IsA("BasePart") and hasTouch(d) then
                    tc = tc + 1
                    if tc <= 40 then print(d:GetFullName()) end
                end
            end
            print("--- Ekran arayüzleri (PlayerGui) ---")
            local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
            if pg then
                for _, g in ipairs(pg:GetChildren()) do print(g.Name .. (g:IsA("ScreenGui") and (g.Enabled and "  [açık]" or "  [kapalı]") or "")) end
            end
            print("--- Lobby resimleri (harita fotoğrafı adayları, ilk 30) ---")
            for i, e in ipairs(imgPool) do
                if i > 30 then break end
                local inst = e.img or e.decal
                if inst then print(inst:GetFullName() .. "  ->  " .. tostring(e.img and e.img.Image or e.decal.Texture)) end
            end
            print("--- Oylama bitiş sinyalleri ---")
            print("Dinlenen: " .. (#hookedSignals > 0 and table.concat(hookedSignals, ", ") or "YOK"))
            pcall(function()
                local gp = RS.Remotes.Gameplay
                local names = {}
                for _, c in ipairs(gp:GetChildren()) do names[#names + 1] = c.ClassName .. ":" .. c.Name end
                print("ReplicatedStorage.Remotes.Gameplay: " .. table.concat(names, ", "))
            end)
            print("Tabela: " .. count .. "  |  Otomatik ped: " .. #pads .. "  |  Kayıtlı ped: " .. #savedRecs)
            notify("Oylama", "Rapor F9 konsoluna yazıldı. Otomatik ped: " .. #pads .. ", kayıtlı: " .. #savedRecs, 4)
        end)
    end)()

    ---------------------------------------------------------
    -- TUŞ DİNLEYİCİ
    ---------------------------------------------------------
    local function hotkeyMatches(input, kcSetting, mouseSetting)
        if mouseSetting and input.UserInputType == mouseSetting then return true end
        if input.UserInputType == Enum.UserInputType.Keyboard and kcSetting and kcSetting ~= Enum.KeyCode.Unknown
            and input.KeyCode == kcSetting then
            return true
        end
        return false
    end

    bind(UserInputService.InputBegan, function(input, gpe)
        if not ready then return end
        if gpe and UserInputService:GetFocusedTextBox() then return end
        if GuiService.MenuIsOpen then return end
        if listening then
            local isKb = input.UserInputType == Enum.UserInputType.Keyboard
            local isMid = input.UserInputType == Enum.UserInputType.MouseButton3
            if not (isKb or isMid) then return end
            local mouseField = listening.key .. "Mouse"
            if isKb then
                local kc = input.KeyCode
                local cur = Settings[listening.key]
                if kc == Enum.KeyCode.Backspace then
                    setText(listening.text, mouseLabel(Settings[mouseField]) or cur.Name)
                    listening = nil
                elseif kc == Settings.ToggleKey or kc == Settings.FlyKey
                    or kc == Settings.MM2ShootKey or kc == Settings.MM2GunKey or kc == Settings.MM2KnifeKey or kc == Settings.MM2InvisKey then
                    setText(listening.text, "Bu tuş kullanımda")
                else
                    Settings[listening.key] = kc
                    Settings[mouseField] = false
                    setText(listening.text, kc.Name)
                    listening = nil
                    saveConfig()
                end
            else
                local midTaken = false
                for _, f in ipairs({"MM2ShootMouse", "MM2GunMouse", "MM2KnifeMouse", "MM2InvisMouse"}) do
                    if f ~= mouseField and Settings[f] == Enum.UserInputType.MouseButton3 then midTaken = true end
                end
                if midTaken then
                    setText(listening.text, "Bu tuş kullanımda")
                else
                    Settings[mouseField] = Enum.UserInputType.MouseButton3
                    Settings[listening.key] = Enum.KeyCode.Unknown
                    setText(listening.text, "🖱️  Orta Tık")
                    listening = nil
                    saveConfig()
                end
            end
            return
        end
        if listeningForKey or listeningFlyKey then return end
        if hotkeyMatches(input, Settings.MM2ShootKey, Settings.MM2ShootMouse) then
            shootTarget()
        elseif hotkeyMatches(input, Settings.MM2GunKey, Settings.MM2GunMouse) then
            task.spawn(function() gotoGun(false) end)
        elseif SFX.knifeOn and hotkeyMatches(input, Settings.MM2KnifeKey, Settings.MM2KnifeMouse) then
            SFX.throwNearest()
        elseif hotkeyMatches(input, Settings.MM2InvisKey, Settings.MM2InvisMouse) then
            if SFX.invisToggle then SFX.invisToggle.Set(not SFX.invisOn) end
        end
    end)

    -- SOL TIK İLE KESKİN VURUŞ: silah elindeyken fareye sol tıklayınca katile otomatik ateş.
    -- gpe (menüye / arayüze tıklama) sayılmaz; silah elde değilse sessizce yok sayılır.
    bind(UserInputService.InputBegan, function(input, gpe)
        if not ready or not SFX.shootLeftOn or gpe or listening then return end
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        if GuiService.MenuIsOpen then return end
        local gun = findGun()
        if gun and LocalPlayer.Character then
            if gun.Parent == LocalPlayer.Character then
                SFX.clickShoot()
            else
                -- Silah elde değil (çantada): shootTarget silahı otomatik ele alıp hemen ateş eder
                task.defer(shootTarget)
            end
        end
    end)

    ---------------------------------------------------------
    -- ÇANTA SAYACI (oyunun coin olayı varsa)
    ---------------------------------------------------------
    task.spawn(function()
        local ev
        for _ = 1, 20 do
            if not alive then return end
            for _, d in ipairs(RS:GetDescendants()) do
                if d.Name == "CoinCollected" and d:IsA("RemoteEvent") then ev = d break end
            end
            if ev then break end
            task.wait(3)
        end
        if ev then
            bind(ev.OnClientEvent, function(...)
                local args = table.pack(...)
                local nums = {}
                for i = 1, args.n do
                    if type(args[i]) == "number" then nums[#nums + 1] = args[i] end
                end
                if #nums >= 2 and nums[2] > 0 then
                    bagNow, bagMax, bagEventSeen = nums[1], nums[2], true
                end
            end)
        end
    end)

    bind(LocalPlayer.CharacterAdded, function()
        task.spawn(recordLobby)
    end)
    task.spawn(recordLobby)

    ---------------------------------------------------------
    -- ARKA PLAN DÖNGÜLERİ
    ---------------------------------------------------------
    task.spawn(function()
        while alive do
            if espOn then
                pcall(applyESP)
            elseif next(espObjs) ~= nil or next(espTags) ~= nil then
                pcall(clearESP)
            end
            task.wait(0.5)
        end
        pcall(clearESP)
    end)
    task.spawn(function()
        while alive do
            pcall(gunWatchStep)
            task.wait(0.2)
        end
        clearGunEsp()
        if topBanner then pcall(function() topBanner:Destroy() end) end
    end)
    task.spawn(function()
        while alive do
            if autoGunOn then pcall(autoGunStep) end
            task.wait(0.25)
        end
    end)
    task.spawn(function()
        while alive do
            if escapeOn then pcall(escapeStep) end
            task.wait(0.12)
        end
    end)
    task.spawn(function()
        while alive do
            if farmOn then
                local ok = pcall(farmStep)
                if not ok then task.wait(0.5) end
                local hEnd = myHRP()
                Settings.FarmLastPos = hEnd and hEnd.Position or nil
            else
                Settings.FarmLastPos = nil
                if noclipConn then releaseFarm() end
                task.wait(0.3)
            end
        end
        releaseFarm()
    end)
end)()

local TrollPage = createTab("Troll", "ツ")
local PremiumPage, PremiumTab = createTab("Premium", "")
local SettingsPage = createTab("Ayarlar", "")
Settings.ChatPage = createTab("Sohbet", "💬")

---------------------------------------------------------
-- 💬 SOHBET: scripti kullanan herkes, farklı Roblox oyunlarında / sunucularında olsa bile mesajlaşabilir.
-- Mesajlar ücretsiz herkese açık bir mesaj aktarıcısı (ntfy.sh) üzerinden geçer. HTTP isteği
-- gönderebilen bir executor (request / http_request) gerekir. Kendi sunucunu kullanmak istersen
-- aşağıdaki CHAT_BASE / CHAT_TOPIC değerlerini değiştir.
---------------------------------------------------------
;(function()
    local CHAT_BASE = "https://ntfy.sh"
    local CHAT_TOPIC = "ezragox-hub-global-chat-7f3a9c"
    local MAX_LEN, SEND_COOLDOWN, MAX_MSGS = 200, 1.5, 120

    local page = Settings.ChatPage
    local req = request or http_request or (syn and syn.request)
    local MarketplaceService = game:GetService("MarketplaceService")

    local gameName = "Bilinmeyen Oyun"
    task.spawn(function()
        local ok, info = pcall(function() return MarketplaceService:GetProductInfo(game.PlaceId) end)
        if ok and info and info.Name then gameName = tostring(info.Name) end
    end)

    local container = new("Frame", {
        LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 330), BackgroundTransparency = 1, ZIndex = 3,
    }, page)
    pcall(function()
        local function fit() container.Size = UDim2.new(1, 0, 0, math.max(300, page.AbsoluteSize.Y - 24)) end
        fit()
        bind(page:GetPropertyChangedSignal("AbsoluteSize"), fit)
    end)

    local status = new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1,
        Text = "🌍  Genel Sohbet  •  Başka oyunlardaki script kullanıcılarıyla yaz. Roblox filtresi yoktur, kişisel bilgi paylaşma.",
        Font = Enum.Font.GothamMedium, TextSize = 11, TextColor3 = Color3.fromRGB(150, 138, 144),
        TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4,
    }, container)

    local list = new("ScrollingFrame", {
        Position = UDim2.new(0, 0, 0, 34), Size = UDim2.new(1, 0, 1, -34 - 46),
        BackgroundColor3 = ROW_BG, BackgroundTransparency = 0.05, BorderSizePixel = 0,
        ScrollBarThickness = 3, ScrollBarImageColor3 = Color3.fromRGB(255, 42, 58),
        CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 4,
    }, container)
    corner(list, 12)
    stroke(list, 1, ROW_STROKE, 0.32)
    new("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4)}, list)
    new("UIPadding", {PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 8)}, list)

    local box = new("TextBox", {
        AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, -88, 0, 38),
        BackgroundColor3 = Color3.fromRGB(28, 14, 20), Text = "", PlaceholderText = "Mesaj yaz...",
        PlaceholderColor3 = Color3.fromRGB(130, 100, 108), TextColor3 = Color3.fromRGB(240, 235, 238),
        TextSize = 13, Font = Enum.Font.GothamMedium, ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5,
    }, container)
    corner(box, 10)
    stroke(box, 1, Color3.fromRGB(135, 40, 55), 0.3)
    new("UIPadding", {PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10)}, box)

    local sendBtn = new("TextButton", {
        AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, 0, 1, 0), Size = UDim2.new(0, 80, 0, 38),
        BackgroundColor3 = Color3.fromRGB(200, 28, 48), AutoButtonColor = false, Text = "Gönder",
        Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = Color3.new(1, 1, 1), ZIndex = 5,
    }, container)
    corner(sendBtn, 10)
    ctaFx(sendBtn, {radius = 10, colors = false})

    local order, count, seen = 0, 0, {}
    local function addMessage(user, display, gname, sameServer, text, mine, system)
        order = order + 1
        count = count + 1
        local f = new("Frame", {
            LayoutOrder = order, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundColor3 = mine and Color3.fromRGB(58, 16, 28) or Color3.fromRGB(30, 15, 21),
            BackgroundTransparency = 0.1, BorderSizePixel = 0, ZIndex = 5,
        }, list)
        corner(f, 8)
        new("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 1)}, f)
        new("UIPadding", {PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 6), PaddingLeft = UDim.new(0, 9), PaddingRight = UDim.new(0, 9)}, f)
        if not system then
            local head = (display ~= user and (display .. " (@" .. user .. ")") or ("@" .. user))
                .. "  •  🎮 " .. gname .. (sameServer and "  •  📍 aynı sunucu" or "")
            new("TextLabel", {
                LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 14), BackgroundTransparency = 1, Text = head,
                Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = mine and Color3.fromRGB(255, 190, 120) or Color3.fromRGB(255, 112, 122),
                TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 6,
            }, f)
        end
        new("TextLabel", {
            LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
            Text = text, RichText = false, TextWrapped = true, Font = Enum.Font.GothamMedium, TextSize = 13,
            TextColor3 = system and Color3.fromRGB(150, 138, 144) or Color3.fromRGB(235, 232, 238),
            TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 6,
        }, f)
        if count > MAX_MSGS then
            for _, c in ipairs(list:GetChildren()) do
                if c:IsA("Frame") then c:Destroy() count = count - 1 break end
            end
        end
        task.defer(function() list.CanvasPosition = Vector2.new(0, 1e6) end)
    end

    if not req then
        addMessage("", "", "", false, "⚠️ Bu executor HTTP isteği (request) desteklemiyor, sohbet çalışmayacak.", false, true)
    else
        addMessage("", "", "", false, "Sohbete bağlanılıyor...", false, true)
    end

    local function clean(s)
        s = tostring(s or ""):gsub("[%c]", " ")
        s = s:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
        return s
    end

    local lastSend = 0
    local function send()
        local text = clean(box.Text)
        if text == "" then return end
        if not req then return end
        if os.clock() - lastSend < SEND_COOLDOWN then
            notify("Sohbet", "Çok hızlı yazıyorsun, biraz bekle.", 2)
            return
        end
        if #text > MAX_LEN then text = string.sub(text, 1, MAX_LEN) end
        lastSend = os.clock()
        box.Text = ""
        local nonce = HttpService:GenerateGUID(false)
        seen[nonce] = true
        addMessage(LocalPlayer.Name, LocalPlayer.DisplayName, gameName, true, text, true)
        task.spawn(function()
            local ok, res = pcall(req, {
                Url = CHAT_BASE .. "/" .. CHAT_TOPIC, Method = "POST",
                Headers = {["Content-Type"] = "text/plain"},
                Body = HttpService:JSONEncode({u = LocalPlayer.Name, d = LocalPlayer.DisplayName, g = gameName, j = game.JobId, m = text, n = nonce}),
            })
            if not ok or type(res) ~= "table" or (res.StatusCode and res.StatusCode >= 400) then
                notify("Sohbet", "Mesaj gönderilemedi (bağlantı / hız sınırı).", 3)
            end
        end)
    end
    bind(sendBtn.MouseButton1Click, function() playClickSound() send() end)
    bind(box.FocusLost, function(enter) if enter then send() end end)

    -- Yeni mesajları periyodik olarak çek
    local lastId, firstPoll, connected = nil, true, false
    task.spawn(function()
        while alive do
            if req then
                local since = lastId or "5m"
                local ok, res = pcall(req, {Url = CHAT_BASE .. "/" .. CHAT_TOPIC .. "/json?poll=1&since=" .. since, Method = "GET"})
                if ok and type(res) == "table" and res.StatusCode == 200 then
                    if not connected then
                        connected = true
                        addMessage("", "", "", false, "✅ Bağlandı. Son 5 dakikadaki mesajlar gösteriliyor.", false, true)
                    end
                    for line in string.gmatch(tostring(res.Body or ""), "[^\r\n]+") do
                        local okj, ev = pcall(function() return HttpService:JSONDecode(line) end)
                        if okj and type(ev) == "table" then
                            if ev.id then lastId = ev.id end
                            if ev.event == "message" and ev.message then
                                local okm, m = pcall(function() return HttpService:JSONDecode(ev.message) end)
                                if okm and type(m) == "table" and m.n and not seen[m.n] and type(m.m) == "string" then
                                    seen[m.n] = true
                                    local u = clean(string.sub(tostring(m.u or "?"), 1, 30))
                                    local d = clean(string.sub(tostring(m.d or u), 1, 30))
                                    local g = clean(string.sub(tostring(m.g or "?"), 1, 40))
                                    local txt = string.sub(clean(m.m), 1, MAX_LEN)
                                    if txt ~= "" then
                                        addMessage(u, d, g, m.j ~= nil and m.j == game.JobId and game.JobId ~= "", txt, false)
                                        if not firstPoll and not page.Visible then
                                            pcall(notify, "💬 " .. d, txt, 3)
                                        end
                                    end
                                end
                            end
                        end
                    end
                    firstPoll = false
                elseif connected then
                    connected = false
                    addMessage("", "", "", false, "⚠️ Bağlantı koptu, yeniden deneniyor...", false, true)
                end
            end
            task.wait(page.Visible and 3 or 8)
        end
    end)
end)()

local AdminPage, AdminTab = createTab("Yönetim", "")

-- ANA SAYFA
do
    local card = new("Frame", {
        LayoutOrder = nextOrder(HomePage), Size = UDim2.new(1, 0, 0, 102),
        BackgroundColor3 = Color3.fromRGB(17, 24, 42), BorderSizePixel = 0, ZIndex = 3,
    }, HomePage)
    corner(card, 14)
    local cs = stroke(card, 1.5, Color3.new(1, 1, 1), 0.25)
    regFlow(UIFlows, new("UIGradient", {}, cs), 2, 0.9, 50)

    local av = new("Frame", {
        Position = UDim2.new(0, 14, 0, 16), Size = UDim2.new(0, 68, 0, 68),
        BackgroundColor3 = Color3.fromRGB(24, 30, 46), BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 4,
    }, card)
    pill(av)
    local avs = stroke(av, 2, Color3.new(1, 1, 1))
    regFlow(UIFlows, new("UIGradient", {}, avs), 0, 0.9, 120)
    local img = new("ImageLabel", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, ZIndex = 5}, av)
    task.spawn(function()
        local ok, content = pcall(function()
            return Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
        end)
        if ok and content then img.Image = content end
    end)

    local shown = LocalPlayer.DisplayName
    if not shown or shown == "" then shown = LocalPlayer.Name end
    new("TextLabel", {
        Position = UDim2.new(0, 96, 0, 16), Size = UDim2.new(1, -210, 0, 26), BackgroundTransparency = 1,
        Text = shown, Font = Enum.Font.GothamBlack, TextSize = 20, TextColor3 = Color3.new(1, 1, 1),
        TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 4,
    }, card)
    new("TextLabel", {
        Position = UDim2.new(0, 96, 0, 46), Size = UDim2.new(1, -110, 0, 16), BackgroundTransparency = 1,
        Text = "@" .. LocalPlayer.Name, Font = Enum.Font.GothamMedium, TextSize = 12,
        TextColor3 = Color3.fromRGB(130, 145, 175), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4,
    }, card)
    new("TextLabel", {
        Position = UDim2.new(0, 96, 0, 68), Size = UDim2.new(1, -110, 0, 16), BackgroundTransparency = 1,
        Text = "Hesap yaşı: " .. tostring(LocalPlayer.AccountAge) .. " gün", Font = Enum.Font.GothamMedium, TextSize = 11,
        TextColor3 = Color3.fromRGB(100, 112, 145), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4,
    }, card)
    new("TextLabel", {
        AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 12), Size = UDim2.new(0, 90, 0, 16),
        BackgroundTransparency = 1, Text = "● BAĞLANDI", Font = Enum.Font.GothamBold, TextSize = 10,
        TextColor3 = Color3.fromRGB(80, 255, 140), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 4,
    }, card)
end

local FpsValue, PingValue, PlayersValue
local ultraFpsDisplayBoost = false -- Yalnızca ana sayfadaki FPS göstergesi için
do
    local row = new("Frame", {
        LayoutOrder = nextOrder(HomePage), Size = UDim2.new(1, 0, 0, 72), BackgroundTransparency = 1, ZIndex = 3,
    }, HomePage)
    new("UIGridLayout", {
        CellSize = UDim2.new(1 / 3, -7, 1, 0), CellPadding = UDim2.new(0, 10, 0, 0), SortOrder = Enum.SortOrder.LayoutOrder,
    }, row)
    local function statCard(order, title)
        local c = new("Frame", {
            LayoutOrder = order, BackgroundColor3 = ROW_BG, BackgroundTransparency = 0.05, BorderSizePixel = 0, ZIndex = 3,
        }, row)
        corner(c, 12)
        stroke(c, 1, ROW_STROKE, 0.2)
        new("TextLabel", {
            Position = UDim2.new(0, 12, 0, 8), Size = UDim2.new(1, -24, 0, 14), BackgroundTransparency = 1,
            Text = title, Font = Enum.Font.GothamBold, TextSize = 10, TextColor3 = Color3.fromRGB(110, 124, 158),
            TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4,
        }, c)
        local v = new("TextLabel", {
            Position = UDim2.new(0, 12, 0, 24), Size = UDim2.new(1, -24, 0, 28), BackgroundTransparency = 1,
            Text = "—", Font = Enum.Font.GothamBlack, TextSize = 22, TextColor3 = Color3.new(1, 1, 1),
            TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4,
        }, c)
        regFlow(UIFlows, new("UIGradient", {}, v), order, 0.5)
        return v
    end
    FpsValue = statCard(1, "FPS")
    PingValue = statCard(2, "PİNG")
    PlayersValue = statCard(3, "OYUNCU")
end

-- Aktif kullanıcı sayısı kartı (veriyi aşağıdaki ağ bölümü doldurur: Settings.ActiveUsersLabel)
do
    local card = new("Frame", {
        LayoutOrder = nextOrder(HomePage), Size = UDim2.new(1, 0, 0, 56),
        BackgroundColor3 = ROW_BG, BackgroundTransparency = 0.05, BorderSizePixel = 0, ZIndex = 3,
    }, HomePage)
    corner(card, 12)
    stroke(card, 1, ROW_STROKE, 0.2)
    local dot = new("Frame", {
        Position = UDim2.new(0, 14, 0.5, -5), Size = UDim2.new(0, 10, 0, 10),
        BackgroundColor3 = Color3.fromRGB(80, 255, 140), BorderSizePixel = 0, ZIndex = 4,
    }, card)
    pill(dot)
    Pulsers[#Pulsers + 1] = {obj = dot, prop = "BackgroundTransparency", base = 0.25, amp = 0.25, speed = 3}
    new("TextLabel", {
        Position = UDim2.new(0, 34, 0, 0), Size = UDim2.new(1, -150, 1, 0), BackgroundTransparency = 1,
        Text = "ŞU AN AKTİF KULLANICI", Font = Enum.Font.GothamBold, TextSize = 11,
        TextColor3 = Color3.fromRGB(110, 124, 158), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4,
    }, card)
    local val = new("TextLabel", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.new(0, 110, 0, 30),
        BackgroundTransparency = 1, Text = "—", Font = Enum.Font.GothamBlack, TextSize = 24,
        TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 4,
    }, card)
    regFlow(UIFlows, new("UIGradient", {}, val), 4, 0.5)
    Settings.ActiveUsersLabel = val
end

do
    local info = new("Frame", {
        LayoutOrder = nextOrder(HomePage), Size = UDim2.new(1, 0, 0, 92),
        BackgroundColor3 = ROW_BG, BackgroundTransparency = 0.05, BorderSizePixel = 0, ZIndex = 3,
    }, HomePage)
    corner(info, 12)
    stroke(info, 1, ROW_STROKE, 0.2)
    new("TextLabel", {
        Position = UDim2.new(0, 14, 0, 10), Size = UDim2.new(1, -28, 0, 18), BackgroundTransparency = 1,
        Text = "EZRAGOX HUB'a hoş geldin!", Font = Enum.Font.GothamBold, TextSize = 14,
        TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4,
    }, info)
    new("TextLabel", {
        Position = UDim2.new(0, 14, 0, 32), Size = UDim2.new(1, -28, 0, 38), BackgroundTransparency = 1,
        Text = "Menüyü G tuşuyla açıp kapatabilirsin. Yapımcı: Hasan Usta",
        Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = Color3.fromRGB(150, 163, 195),
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true, ZIndex = 4,
    }, info)
end

-- Ana sayfa Premium CTA: Discord logosu metnin sonunda; tıklanınca davet bağlantısı panoya kopyalanır.
-- Efektler: üstüne gelince yumuşak büyüme + ışık süpürmesi + logo eğilir + "tik-ti" sesi;
--           basınca içeri çöker + dokunma dalgası + kıvılcım + bas tıkı;
--           bırakınca yaylanarak geri döner; tıklanınca onay sesi + logo tam tur döner + yeşil flaş.
do
    local BASE_BG = Color3.fromRGB(29, 13, 22)
    local HOVER_BG = Color3.fromRGB(46, 16, 30)
    local PRESS_BG = Color3.fromRGB(62, 18, 36)
    local BASE_STROKE = Color3.fromRGB(190, 35, 55)
    local HOT_STROKE = Color3.fromRGB(255, 70, 85)

    -- Dış düğme yalnızca tıklama alanıdır; görünen yüz ("face") ortadan ölçeklenir.
    local premiumCta = new("TextButton", {
        LayoutOrder = nextOrder(HomePage),
        Size = UDim2.new(1, 0, 0, 70),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = "",
        ZIndex = 4,
    }, HomePage)

    local face = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = BASE_BG,
        BackgroundTransparency = 0.04,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        ZIndex = 4,
    }, premiumCta)
    corner(face, 13)
    local faceStroke = stroke(face, 1.2, BASE_STROKE, 0.12)
    local faceScale = new("UIScale", {Scale = 1}, face)

    local label = new("TextLabel", {
        Position = UDim2.new(0, 18, 0, 0),
        Size = UDim2.new(1, -88, 1, 0),
        BackgroundTransparency = 1,
        Text = "PREMIUM ALMAK İÇİN TIKLA  ›",
        Font = Enum.Font.GothamBlack,
        TextSize = 14,
        TextColor3 = Color3.fromRGB(255, 105, 115),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true,
        ZIndex = 5,
    }, face)
    local logo = new("ImageLabel", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -12, 0.5, 0),
        Size = UDim2.new(0, 48, 0, 48),
        BackgroundTransparency = 1,
        Image = "rbxassetid://124899140068285",
        ScaleType = Enum.ScaleType.Fit,
        ZIndex = 5,
    }, face)

    -- Üstüne gelince geçen cam parlaması
    local shine = new("Frame", {
        Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0, ZIndex = 7, Visible = false,
    }, face)
    corner(shine, 13)
    local shineGrad = new("UIGradient", {
        Rotation = 20,
        Offset = Vector2.new(-1, 0),
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.4, 1),
            NumberSequenceKeypoint.new(0.5, 0.82),
            NumberSequenceKeypoint.new(0.6, 1),
            NumberSequenceKeypoint.new(1, 1),
        }),
    }, shine)

    local hovering, pressed = false, false
    local shineRun = 0
    local function sweepShine()
        shineRun = shineRun + 1
        local my = shineRun
        shineGrad.Offset = Vector2.new(-1, 0)
        shine.Visible = true
        tween(shineGrad, 0.6, {Offset = Vector2.new(1, 0)}, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
        task.delay(0.65, function()
            if shineRun == my then shine.Visible = false end
        end)
    end

    -- Dokunma dalgası + kıvılcımlar (fx: dokunulan yatay konum, 0..1)
    local function touchFx(fx)
        local r = new("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(fx, 0, 0.5, 0),
            Size = UDim2.new(0, 0, 0, 0),
            BackgroundColor3 = Color3.fromRGB(255, 120, 130),
            BackgroundTransparency = 0.55,
            BorderSizePixel = 0, ZIndex = 6,
        }, face)
        pill(r)
        tween(r, 0.6, {Size = UDim2.new(0, 520, 0, 520), BackgroundTransparency = 1}, Enum.EasingStyle.Quint)
        task.delay(0.65, function() r:Destroy() end)
        for i = 1, 8 do
            local a = (i / 8) * math.pi * 2 + math.random() * 0.5
            local d = math.random(26, 74)
            local sz = math.random(3, 5)
            local sp = new("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(fx, 0, 0.5, 0),
                Size = UDim2.new(0, sz, 0, sz),
                BackgroundColor3 = (i % 2 == 0) and Color3.new(1, 1, 1) or Color3.fromRGB(255, 90, 105),
                BorderSizePixel = 0, ZIndex = 6,
            }, face)
            pill(sp)
            local dur = 0.3 + math.random() * 0.2
            tween(sp, dur, {
                Position = UDim2.new(fx, math.cos(a) * d, 0.5, math.sin(a) * d),
                BackgroundTransparency = 1,
            }, Enum.EasingStyle.Quad)
            task.delay(dur + 0.05, function() sp:Destroy() end)
        end
    end

    local function restState(animTime)
        tween(face, animTime, {BackgroundColor3 = hovering and HOVER_BG or BASE_BG}, Enum.EasingStyle.Quint)
        tween(faceStroke, animTime, {
            Color = hovering and HOT_STROKE or BASE_STROKE,
            Transparency = hovering and 0 or 0.12,
            Thickness = hovering and 2 or 1.2,
        }, Enum.EasingStyle.Quint)
    end

    -- ÜSTÜNE GELİNCE
    bind(premiumCta.MouseEnter, function()
        hovering = true
        if not pressed then
            tween(faceScale, 0.25, {Scale = 1.025}, Enum.EasingStyle.Back)
        end
        restState(0.2)
        tween(logo, 0.3, {Rotation = -10, Size = UDim2.new(0, 54, 0, 54)}, Enum.EasingStyle.Back)
        tween(label, 0.2, {TextColor3 = Color3.fromRGB(255, 150, 158)}, Enum.EasingStyle.Quad)
        sweepShine()
        -- "tik-ti": iki kısa, yükselen tık
        playSound(1.85, 0.12)
        task.delay(0.055, function() playSound(2.3, 0.09) end)
    end)
    bind(premiumCta.MouseLeave, function()
        hovering = false
        pressed = false
        tween(faceScale, 0.25, {Scale = 1}, Enum.EasingStyle.Quint)
        restState(0.24)
        tween(logo, 0.25, {Rotation = 0, Size = UDim2.new(0, 48, 0, 48)}, Enum.EasingStyle.Quint)
        tween(label, 0.24, {TextColor3 = Color3.fromRGB(255, 105, 115)}, Enum.EasingStyle.Quad)
    end)

    -- BASINCA (fare ya da dokunmatik)
    bind(premiumCta.InputBegan, function(input)
        local ut = input.UserInputType
        if ut ~= Enum.UserInputType.MouseButton1 and ut ~= Enum.UserInputType.Touch then return end
        pressed = true
        tween(faceScale, 0.07, {Scale = 0.955}, Enum.EasingStyle.Quad)
        tween(face, 0.07, {BackgroundColor3 = PRESS_BG}, Enum.EasingStyle.Quad)
        tween(faceStroke, 0.07, {Color = Color3.new(1, 1, 1), Transparency = 0, Thickness = 2.6}, Enum.EasingStyle.Quad)
        local fx = 0.5
        pcall(function()
            fx = math.clamp((input.Position.X - premiumCta.AbsolutePosition.X) / premiumCta.AbsoluteSize.X, 0, 1)
        end)
        touchFx(fx)
        playSound(1.0, 0.22) -- hafif "bas" tıkı
    end)
    -- BIRAKINCA: yaylanarak geri döner
    bind(premiumCta.InputEnded, function(input)
        local ut = input.UserInputType
        if ut ~= Enum.UserInputType.MouseButton1 and ut ~= Enum.UserInputType.Touch then return end
        if not pressed then return end
        pressed = false
        tween(faceScale, 0.34, {Scale = hovering and 1.025 or 1}, Enum.EasingStyle.Back)
        restState(0.25)
    end)

    -- TIKLANDIKTAN SONRA: onay sesi + logo tam tur + yeşil flaş, sonra bağlantıyı kopyala
    bind(premiumCta.Activated, function()
        playClickSound()
        task.delay(0.08, function() playSound(2.0, 0.35) end)
        task.delay(0.17, function() playSound(2.7, 0.3) end)

        local baseRot = logo.Rotation
        tween(logo, 0.7, {Rotation = baseRot + 360}, Enum.EasingStyle.Quint)
        task.delay(0.75, function() logo.Rotation = baseRot end)
        tween(faceStroke, 0.12, {Color = Color3.fromRGB(70, 235, 130), Transparency = 0, Thickness = 3}, Enum.EasingStyle.Quad)
        task.delay(0.7, function() if alive then restState(0.3) end end)

        local copied = false
        if setclipboard then
            copied = pcall(function() setclipboard(DISCORD_URL) end)
        end
        if not copied and toclipboard then
            copied = pcall(function() toclipboard(DISCORD_URL) end)
        end
        if copied then
            notifyTop("Discord adresi kopyalandı ✅", 3)
        else
            notifyTop("Discord: " .. DISCORD_URL, 6)
        end
    end)
end

-- ÖZELLİKLER SEKMESİ
-- 🖥️ EKRAN GENİŞLETME: Roblox oyun görüntüsünü yatayda uzatır ("stretched resolution" / geniş ekran görünümü).
-- Kamera görüntüsü dikeyde sıkıştırılır, böylece dünya ve karakterler enlemesine genişlemiş görünür. Menü boyutundan bağımsızdır.
createSection(FeaturesPage, "İMLEÇ ÖZELLEŞTİRME")
;(function()
    local styles = {
        "🎯", "⭐", "💎", "🔥", "⚡", "👾", "🌀", "☠️",
        "🌈", "🦇", "🕹️", "❄️", "🍀", "🐉", "👑", "💀",
    }
    local selected = Settings.CursorStyle or styles[1]
    local size = math.clamp(tonumber(Settings.CursorSize) or 32, 18, 64)
    local spinning = Settings.CursorSpin == true
    local enabled = false
    local angle = 0
    local cursorGui = new("TextLabel", {
        Name = "EZRAGOX_CustomCursor",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromOffset(0, 0),
        Size = UDim2.fromOffset(size, size),
        BackgroundTransparency = 1,
        Text = selected,
        TextSize = size,
        Font = Enum.Font.GothamBlack,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextStrokeColor3 = Color3.fromRGB(25, 10, 20),
        TextStrokeTransparency = 0.12,
        Visible = false,
        ZIndex = 10000,
    }, ScreenGui)

    local function refreshCursor()
        cursorGui.Text = selected
        cursorGui.TextSize = size
        cursorGui.Size = UDim2.fromOffset(size + 8, size + 8)
        Settings.CursorStyle = selected
        Settings.CursorSize = size
        Settings.CursorSpin = spinning
        saveConfig()
    end

    createToggle(FeaturesPage, "🖱️  Özel İmleç", false, function(v)
        enabled = v
        cursorGui.Visible = v
        UserInputService.MouseIconEnabled = not v
        if not v then cursorGui.Rotation = 0 end
    end)

    -- İmleç seçenekleri kapalı başlar; tıklanınca stiller ve ayarlar açılır.
    local cursorOptionsOpen = false
    local cursorOptionsFrame
    local cursorOptionsButtonLabel
    local cursorOptionsButton = createButton(FeaturesPage, "🎨  İmleçleri Göster  +", function()
        cursorOptionsOpen = not cursorOptionsOpen
        if cursorOptionsFrame then cursorOptionsFrame.Visible = cursorOptionsOpen end
        if cursorOptionsButtonLabel then
            cursorOptionsButtonLabel.Text = cursorOptionsOpen and "🎨  İmleçleri Gizle  −" or "🎨  İmleçleri Göster  +"
        end
    end)

    cursorOptionsFrame = new("Frame", {
        Name = "EZRAGOX_CursorOptions",
        LayoutOrder = nextOrder(FeaturesPage),
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Visible = false,
        ZIndex = 3,
    }, FeaturesPage)
    local cursorOptionsLayout = new("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 6),
    }, cursorOptionsFrame)
    cursorOptionsButtonLabel = cursorOptionsButton:FindFirstChildWhichIsA("TextLabel")
    if cursorOptionsButtonLabel then
        cursorOptionsButtonLabel.Text = "🎨  İmleçleri Göster  +"
    end

    for _, style in ipairs(styles) do
        createButton(cursorOptionsFrame, style .. "  " .. style .. " imlecini seç", function()
            selected = style
            refreshCursor()
        end)
    end

    createSection(cursorOptionsFrame, "İMLEÇ AYARLARI")
    createSlider(cursorOptionsFrame, "📏  İmleç Boyutu", 18, 64, size, function(v)
        size = v
        refreshCursor()
    end, " px")
    createToggle(cursorOptionsFrame, "🌀  İmleç Dönüşü", spinning, function(v)
        spinning = v
        refreshCursor()
    end)

    local renderConn
    renderConn = RunService.RenderStepped:Connect(function(dt)
        if not alive then
            if renderConn then renderConn:Disconnect() end
            cursorGui.Visible = false
            pcall(function() UserInputService.MouseIconEnabled = true end)
            return
        end
        if enabled and cursorGui.Parent then
            local pos = UserInputService:GetMouseLocation()
            cursorGui.Position = UDim2.fromOffset(pos.X, pos.Y)
            if spinning then
                angle = (angle + dt * 180) % 360
                cursorGui.Rotation = angle
            else
                cursorGui.Rotation = 0
            end
        end
    end)
    refreshCursor()
end)()

createSection(FeaturesPage, "EKRAN GENİŞLETME")
;(function()
    local NAME = "EZRAGOX_StretchScreen"
    local on, amount = false, 35 -- amount: yüzde (0 = normal)
    local mouseObj = LocalPlayer:GetMouse()
    local origCF = nil          -- gerilmemiş (gerçek) kamera CFrame'i
    local hbConn = nil
    local cachedInset = Vector2.new(0, 0)
    local hooksInstalled = false

    local function vScale() return math.clamp(1 - amount / 100, 0.2, 1) end

    -- Gerilmiş görüntüde imlecin altındaki dünya noktası, gerilmemiş kameraya göre
    -- dikeyde "ekran merkezinden uzaklık x ölçek" kadar yukarı/aşağıdadır.
    -- Bu yüzden oyuna giden tıklama noktasının Y'sini merkeze doğru ölçekliyoruz.
    local function fixViewportY(y)
        local cam = workspace.CurrentCamera
        if not cam then return y end
        local cy = cam.ViewportSize.Y / 2
        return cy + (y - cy) * vScale()
    end

    local function unbind()
        pcall(function() RunService:UnbindFromRenderStep(NAME) end)
        if hbConn then hbConn:Disconnect() hbConn = nil end
        -- kamerayı gerilmemiş haline geri ver
        local cam = workspace.CurrentCamera
        if cam and origCF then pcall(function() cam.CFrame = origCF end) end
        origCF = nil
    end

    -- Oyunun fare/ışın okumalarını gerilmiş görüntüye göre düzelt (mermi, bıçak vb. tıkladığın yere gitsin)
    local function installHooks()
        if hooksInstalled then return end
        if not (hookmetamethod and getnamecallmethod) then return end
        hooksInstalled = true

        -- 1) Camera:ViewportPointToRay / ScreenPointToRay
        pcall(function()
            local oldNC
            local function ncHandler(self, ...)
                if on and alive then
                    local method = getnamecallmethod()
                    if (method == "ViewportPointToRay" or method == "ScreenPointToRay")
                        and rawequal(self, workspace.CurrentCamera) then
                        local x, y, d = ...
                        if type(x) == "number" and type(y) == "number" then
                            local ny
                            if method == "ScreenPointToRay" then
                                ny = fixViewportY(y + cachedInset.Y) - cachedInset.Y
                            else
                                ny = fixViewportY(y)
                            end
                            if setnamecallmethod then setnamecallmethod(method) end
                            return oldNC(self, x, ny, d)
                        end
                        if setnamecallmethod then setnamecallmethod(method) end
                    end
                end
                return oldNC(self, ...)
            end
            oldNC = hookmetamethod(game, "__namecall", newcclosure and newcclosure(ncHandler) or ncHandler)
        end)

        -- 2) Mouse.Hit / Target / UnitRay / Origin
        pcall(function()
            local oldIndex
            local function mouseRay()
                local cam = workspace.CurrentCamera
                local loc = UserInputService:GetMouseLocation()
                return cam:ViewportPointToRay(loc.X, fixViewportY(loc.Y))
            end
            local function idxHandler(self, key)
                if on and alive and (key == "Hit" or key == "Target" or key == "UnitRay" or key == "Origin")
                    and rawequal(self, mouseObj) then
                    local ok, res = pcall(function()
                        local ray = mouseRay()
                        if key == "UnitRay" then return ray end
                        if key == "Origin" then return CFrame.new(ray.Origin) end
                        local params = RaycastParams.new()
                        params.FilterType = Enum.RaycastFilterType.Exclude
                        local ign = {}
                        local ch = LocalPlayer.Character
                        if ch then ign[#ign + 1] = ch end
                        local tf = oldIndex(mouseObj, "TargetFilter")
                        if typeof(tf) == "Instance" then ign[#ign + 1] = tf end
                        params.FilterDescendantsInstances = ign
                        local hit = workspace:Raycast(ray.Origin, ray.Direction.Unit * 1000, params)
                        if key == "Target" then return hit and hit.Instance or nil end
                        local pos = hit and hit.Position or (ray.Origin + ray.Direction.Unit * 1000)
                        return CFrame.new(pos)
                    end)
                    if ok then return res end
                end
                return oldIndex(self, key)
            end
            oldIndex = hookmetamethod(game, "__index", newcclosure and newcclosure(idxHandler) or idxHandler)
        end)
    end

    local function start()
        unbind()
        installHooks()
        cachedInset = GuiService:GetGuiInset()

        -- Her karede: kamera düzenlendikten sonra görüntüyü dikeyde sıkıştır
        RunService:BindToRenderStep(NAME, Enum.RenderPriority.Camera.Value + 1, function()
            if not alive or not on then unbind() return end
            local cam = workspace.CurrentCamera
            if cam then
                origCF = cam.CFrame
                cam.CFrame = origCF * CFrame.new(0, 0, 0, 1, 0, 0, 0, vScale(), 0, 0, 0, 1)
            end
        end)

        -- Kare çizildikten sonra (Heartbeat) kamerayı gerçek haline geri al:
        -- fare tıklamaları / ışınlar bir sonraki karede bozulmamış kamerayla hesaplanır.
        hbConn = RunService.Heartbeat:Connect(function()
            local cam = workspace.CurrentCamera
            if cam and origCF then cam.CFrame = origCF end
            local ok, ins = pcall(function() return GuiService:GetGuiInset() end)
            if ok and ins then cachedInset = ins end
        end)
    end

    createToggle(FeaturesPage, "🖥️  Ekranı Yatay Genişlet (Geniş Ekran)", false, function(v)
        on = v
        if v then start() else unbind() end
    end)
    createSlider(FeaturesPage, "↔️  Genişlik", 5, 60, amount, function(v)
        amount = v
    end, "%")
end)()

createSection(FeaturesPage, "KARAKTER ÖZELLİKLERİ")

local ghostActive = false
createToggle(FeaturesPage, "👻  Hayalet Modu (Görünmezlik)", false, function(v)
    ghostActive = v
    pcall(function()
        local char = LocalPlayer.Character
        if char then
            for _, d in ipairs(char:GetDescendants()) do
                if d:IsA("BasePart") or d:IsA("Decal") then
                    if d.Name ~= "HumanoidRootPart" then
                        d.Transparency = ghostActive and 1 or 0
                    end
                end
            end
        end
    end)
    notify("Hayalet Modu", ghostActive and "Görünmez oldun!" or "Görünür hale geldin.", 2)
end)

-- 🛡️ Doğuş Kalkanı: Roblox'un doğduğunda verdiği mavi ForceField kalkanı (açılır/kapanır)
do
    local shieldActive = false
    local SHIELD_NAME = "EZRAGOX_Shield"

    local function removeShield(char)
        if not char then return end
        for _, d in ipairs(char:GetChildren()) do
            if d:IsA("ForceField") and d.Name == SHIELD_NAME then
                d:Destroy()
            end
        end
    end

    local function applyShield(char)
        if not char then return end
        removeShield(char)
        local ff = Instance.new("ForceField")
        ff.Name = SHIELD_NAME
        ff.Visible = true
        ff.Parent = char
    end

    shieldCleanup = function()
        shieldActive = false
        removeShield(LocalPlayer.Character)
    end

    createToggle(FeaturesPage, "🛡️  Doğuş Kalkanı (Mavi Kalkan)", false, function(v)
        shieldActive = v
        pcall(function()
            if shieldActive then
                applyShield(LocalPlayer.Character)
            else
                removeShield(LocalPlayer.Character)
            end
        end)
        notify("Doğuş Kalkanı", shieldActive and "Mavi kalkanın içindesin!" or "Kalkan kaldırıldı.", 2)
    end)

    -- Ölüp yeniden doğunca açıksa kalkanı tekrar ver
    bind(LocalPlayer.CharacterAdded, function(char)
        if not shieldActive then return end
        task.wait(0.3)
        if alive and shieldActive and char and char.Parent then
            pcall(applyShield, char)
        end
    end)

    -- Başka bir script kalkanı silerse geri koy
    task.spawn(function()
        while alive do
            task.wait(1)
            if shieldActive then
                pcall(function()
                    local char = LocalPlayer.Character
                    if char and not char:FindFirstChild(SHIELD_NAME) then
                        applyShield(char)
                    end
                end)
            end
        end
    end)
end


-- Anti-Fling (YARHM portu): YARHM Universal modulundeki "Anti-fling" mantigi.
-- 1) BASKALARINI IZLER: hizi / donusu fling seviyesine cikan oyuncunun butun parcalarinin
--    carpismasini kapatir ve hizlarini sifirlar -> sana carpip seni firlatamaz.
-- 2) SENI IZLER: kendi karakterin 250 stud/sn ustu hiz ya da donus alirsa hizi sifirlar ve
--    seni son guvenli konumuna geri koyar.
-- HEM Ozellikler sayfasinda HEM MM2 sayfasinda ayni anahtari acar (ikisi birbirini yansitir).
do
    local antiFlingOn = false
    local toggles = {}
    local steppedCon, heartbeatCon, neutralCon = nil, nil, nil
    local lastPos = nil
    local lastWarn = 0
    local detected = {}                                  -- bildirim tekrarini engeller
    local changed = setmetatable({}, {__mode = "k"})     -- degistirdigimiz parcalarin eski degerleri

    -- Kendi fling ozelligini kullanirken (FlingKit) anti-fling araya girmesin
    local function flingBusy()
        local kit = Settings.FlingKit
        return (kit and kit.isBusy and kit.isBusy()) and true or false
    end

    local function rootOf(ch)
        return ch and (ch.PrimaryPart or ch:FindFirstChild("HumanoidRootPart"))
    end

    -- (1) Fling yapan oyuncunun carpismasini kapat
    local function neutralizeFlingers()
        if flingBusy() then return end
        for _, pl in ipairs(Players:GetPlayers()) do
            if pl ~= LocalPlayer then
                local ch = pl.Character
                local root = rootOf(ch)
                if root and ch:IsDescendantOf(workspace) then
                    if root.AssemblyAngularVelocity.Magnitude > 50 or root.AssemblyLinearVelocity.Magnitude > 100 then
                        if not detected[pl.Name] then
                            detected[pl.Name] = true
                            pcall(notifyTop, "🛡️ Flinger tespit edildi: " .. pl.Name, 2.5)
                        end
                        for _, p in ipairs(ch:GetDescendants()) do
                            if p:IsA("BasePart") then
                                if not changed[p] then
                                    changed[p] = {cc = p.CanCollide, cpp = p.CustomPhysicalProperties}
                                end
                                p.CanCollide = false
                                p.AssemblyAngularVelocity = Vector3.zero
                                p.AssemblyLinearVelocity = Vector3.zero
                                pcall(function() p.CustomPhysicalProperties = PhysicalProperties.new(0, 0, 0) end)
                            end
                        end
                    end
                end
            end
        end
    end

    -- (2) Kendi karakterini savrulmaktan koru
    local function neutralizeSelf()
        local pp = rootOf(LocalPlayer.Character)
        if not pp then return end
        -- Fly acikken hizi biz degistiriyoruz: engelleme, sadece guvenli konumu guncelle
        if Settings.FlyActive then
            lastPos = pp.Position
            return
        end
        if flingBusy() then return end
        if pp.AssemblyLinearVelocity.Magnitude > 250 or pp.AssemblyAngularVelocity.Magnitude > 250 then
            pp.AssemblyLinearVelocity = Vector3.zero
            pp.AssemblyAngularVelocity = Vector3.zero
            if lastPos then pp.CFrame = CFrame.new(lastPos) end
            local now = os.clock()
            if now - lastWarn > 2 then
                lastWarn = now
                pcall(notifyTop, "🛡️ Savrulma engellendi! Hizin sifirlandi.", 1.8)
            end
        else
            lastPos = pp.Position
        end
    end

    local function drop(c)
        if c then pcall(function() c:Disconnect() end) end
    end

    -- Kapatinca baskalarinin carpismasini eski haline getir
    local function restoreOthers()
        for p, old in pairs(changed) do
            if p and p.Parent then
                pcall(function()
                    p.CanCollide = old.cc
                    p.CustomPhysicalProperties = old.cpp
                end)
            end
            changed[p] = nil
        end
    end

    local function setEnabled(v)
        antiFlingOn = v and true or false
        if antiFlingOn then
            lastPos, lastWarn = nil, 0
            detected = {}
            -- Stepped = fizikten ONCE, Heartbeat = fizikten SONRA: ikisinde de calisir
            if not steppedCon then steppedCon = RunService.Stepped:Connect(neutralizeFlingers) end
            if not heartbeatCon then heartbeatCon = RunService.Heartbeat:Connect(neutralizeFlingers) end
            if not neutralCon then neutralCon = RunService.Heartbeat:Connect(neutralizeSelf) end
        else
            drop(steppedCon); steppedCon = nil
            drop(heartbeatCon); heartbeatCon = nil
            drop(neutralCon); neutralCon = nil
            lastPos = nil
            restoreOthers()
        end
    end

    bind(LocalPlayer.CharacterAdded, function() lastPos = nil end)

    antiFlingCleanup = function()
        setEnabled(false)
    end

    makeAntiFlingToggle = function(page)
        local t
        t = createToggle(page, "🛡️  Anti-Fling (Savrulma Engelleyici - En Guclu Mod)", false, function(v)
            setEnabled(v)
            pcall(notifyTop, v and "🛡️ Anti-Fling ACIK" or "🛡️ Anti-Fling KAPALI", 2)
            for _, o in ipairs(toggles) do
                if o ~= t then pcall(o.Set, v, true) end
            end
        end)
        toggles[#toggles + 1] = t
        return t
    end

    makeAntiFlingToggle(FeaturesPage)
end

if Settings.FlingKit then Settings.FlingKit.buildFeatures(FeaturesPage) end

-- 🏃‍♂️ Süper Hız: yeni raund başlayınca / karakter oyun tarafından sıfırlanınca
-- (CharacterAdded hiç tetiklenmese bile) hız eski haline dönmesin diye sürekli izlenir.
do
    local speedActive = false

    local function enforceSpeed()
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum and math.abs(hum.WalkSpeed - Settings.SpeedVal) > 0.01 then
            hum.WalkSpeed = Settings.SpeedVal
        end
    end

    createToggle(FeaturesPage, "🏃‍♂️  Süper Hız Aktif Et", false, function(v)
        speedActive = v
        pcall(function()
            local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum then
                hum.WalkSpeed = v and Settings.SpeedVal or 16
            end
        end)
        notify("Süper Hız", v and "Hızın artırıldı! (Her raundda otomatik korunur)" or "Normale döndü.", 2)
    end)

    createSlider(FeaturesPage, "⚡  Süper Hız Değeri", 16, 200, Settings.SpeedVal, function(v)
        Settings.SpeedVal = v
        if speedActive then pcall(enforceSpeed) end
    end, "")

    -- Karakter yenilenince (ölüp doğunca): oyunun kendi doğuş script'i WalkSpeed'i
    -- ayarlamayı bitirsin diye kısa süre beklenir, sonra üstüne yazılır.
    bind(LocalPlayer.CharacterAdded, function(char)
        if not speedActive then return end
        task.spawn(function()
            local hum = char:WaitForChild("Humanoid", 10)
            task.wait(0.5)
            if alive and speedActive and hum and hum.Parent and LocalPlayer.Character == char then
                hum.WalkSpeed = Settings.SpeedVal
            end
        end)
    end)

    -- Raund değişince (karakter hiç yenilenmeden) oyunun kendi script'i hızı sıfırlarsa
    -- bu döngü anında fark edip yeniden uygular. Asıl düzeltme burada.
    task.spawn(function()
        while alive do
            task.wait(0.15)
            if speedActive then pcall(enforceSpeed) end
        end
    end)
end

createToggle(FeaturesPage, "🚀  Süper Zıplama Gücü", false, function(v)
    pcall(function()
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.UseJumpPower = true
            hum.JumpPower = v and 120 or 50
        end
    end)
    notify("Süper Zıplama", v and "Zıplama gücü artırıldı!" or "Normale döndü.", 2)
end)

local infJumpActive = false
createToggle(FeaturesPage, "🦘  Sınırsız Zıplama (Infinite Jump)", false, function(v)
    infJumpActive = v
    notify("Sınırsız Zıplama", v and "Aktif edildi!" or "Kapatıldı.", 2)
end)

bind(UserInputService.JumpRequest, function()
    if infJumpActive then
        pcall(function()
            local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum then
                hum:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end)
    end
end)

-- Dokunduğun / sana değen oyuncuyu hafifçe ileri iter
do
    local pushOn, pushPower = false, 3
    local lastPush = {}
    bind(RunService.Heartbeat, function()
        if not pushOn then return end
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        local look = hrp.CFrame.LookVector
        local flat = Vector3.new(look.X, 0, look.Z)
        if flat.Magnitude < 0.01 then return end
        flat = flat.Unit
        local now = os.clock()
        for _, plr in ipairs(Players:GetPlayers()) do
            local oc = plr ~= LocalPlayer and plr.Character
            local oh = oc and oc:FindFirstChild("HumanoidRootPart")
            if oh then
                local d = oh.Position - hrp.Position
                local dist = Vector3.new(d.X, 0, d.Z).Magnitude
                if dist <= 4.5 and math.abs(d.Y) <= 5 and (lastPush[plr] or 0) + 0.35 < now then
                    lastPush[plr] = now
                    pcall(function()
                        local v = oh.AssemblyLinearVelocity
                        oh.AssemblyLinearVelocity = Vector3.new(flat.X * pushPower * 8, v.Y, flat.Z * pushPower * 8)
                    end)
                end
            end
        end
    end)

    createToggle(FeaturesPage, "🫸  Dokunduğun Kişiyi İleri İt", false, function(v)
        pushOn = v
        if not v then lastPush = {} end
        notify("İtme Modu", v and "Aktif! Sana değen oyuncu ileri itilir." or "Kapatıldı.", 2)
    end)

    createSlider(FeaturesPage, "💪  İtme Gücü", 1, 10, 3, function(v)
        pushPower = v
    end, "")
end

-- 👥 OYUNCULARIN İÇİNDEN GEÇ: diğer oyuncuların karakterlerinin çarpışmasını SADECE senin istemcinde kapatır.
-- Sana değip seni itemezler / engel olamazlar; sen de onların içinden geçersin. Başkaları seni etkilenmiş görmez.
createSection(FeaturesPage, "OYUNCU ÇARPIŞMASI")
;(function()
    local on = false
    local conn = nil
    local cache = {}                                        -- her oyuncu için BasePart listesi
    local changed = setmetatable({}, {__mode = "k"})        -- çarpışmasını biz kapattığımız parçalar
    local lastRefresh = 0

    local function refresh()
        cache = {}
        for _, pl in ipairs(Players:GetPlayers()) do
            local ch = pl.Character
            if pl ~= LocalPlayer and ch then
                local list = {}
                for _, d in ipairs(ch:GetDescendants()) do
                    if d:IsA("BasePart") then list[#list + 1] = d end
                end
                cache[#cache + 1] = list
            end
        end
    end

    -- Fizikten ÖNCE her karede kapat (Humanoid çarpışmayı her adımda geri açar)
    local function step()
        if not alive or not on then return end
        local now = os.clock()
        if now - lastRefresh > 0.5 then
            lastRefresh = now
            refresh()
        end
        for _, list in ipairs(cache) do
            for _, p in ipairs(list) do
                if p.Parent and p.CanCollide then
                    changed[p] = true
                    p.CanCollide = false
                end
            end
        end
    end

    local function restore()
        for p in pairs(changed) do
            if p and p.Parent then pcall(function() p.CanCollide = true end) end
            changed[p] = nil
        end
    end

    local function setOn(v)
        on = v and true or false
        if on then
            lastRefresh = 0
            if not conn then conn = RunService.Stepped:Connect(step) end
        else
            if conn then conn:Disconnect() conn = nil end
            cache = {}
            restore()
        end
    end

    createToggle(FeaturesPage, "👥  Oyuncuların İçinden Geç  (İtilme Engeli)", false, function(v)
        setOn(v)
        notify("Oyuncu Çarpışması", v and "Aktif! Artık kimse seni itemez, oyuncuların içinden geçersin." or "Kapatıldı. Çarpışma normale döndü.", 3)
    end)

    task.spawn(function()
        while alive do task.wait(1) end
        setOn(false)
    end)
end)()

createSection(FeaturesPage, "UÇUŞ MODU (FLY)")

do
local flyActive = false
local flyConnection = nil
local flyBv, flyBg = nil, nil
local flyHumanoid = nil
local flyOldAutoRotate = nil
local flyOldJumpingEnabled = nil
local flyOldFreefallEnabled = nil
local flyAnimateScript = nil
local flyOldAnimateEnabled = nil

local function stopFlyMovers()
    if flyConnection then flyConnection:Disconnect(); flyConnection = nil end
    if flyBv then pcall(function() flyBv:Destroy() end); flyBv = nil end
    if flyBg then pcall(function() flyBg:Destroy() end); flyBg = nil end
end

local function attachFlyMovers(hrp)
    if flyBv then pcall(function() flyBv:Destroy() end) end
    if flyBg then pcall(function() flyBg:Destroy() end) end
    flyBv = Instance.new("BodyVelocity")
    flyBv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    flyBv.Velocity = Vector3.zero
    flyBv.Parent = hrp

    flyBg = Instance.new("BodyGyro")
    flyBg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    flyBg.P = 90000
    flyBg.D = 1000
    flyBg.CFrame = CFrame.lookAt(hrp.Position, hrp.Position + Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z))
    flyBg.Parent = hrp
end

local function toggleFly(v, silent)
    flyActive = v
    Settings.FlyActive = v -- Anti-Fling kendi uçuşumuzu engellemesin
    pcall(function()
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if flyActive and hrp and hum then
            -- Eski karakterden / önceki açılıştan kalan bağlantıları temizle
            stopFlyMovers()
            if flyHumanoid ~= hum then
                flyHumanoid = hum
                flyOldAutoRotate = hum.AutoRotate
                flyOldJumpingEnabled = hum:GetStateEnabled(Enum.HumanoidStateType.Jumping)
                flyOldFreefallEnabled = hum:GetStateEnabled(Enum.HumanoidStateType.Freefall)
                flyAnimateScript = char:FindFirstChild("Animate")
                if flyAnimateScript and flyAnimateScript:IsA("LocalScript") then
                    flyOldAnimateEnabled = flyAnimateScript.Enabled
                    flyAnimateScript.Enabled = false
                end
            end

            -- Uçuş sırasında varsayılan yürüme/koşma/zıplama animasyonlarını durdur.
            local animator = hum:FindFirstChildOfClass("Animator")
            if animator then
                for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                    track:Stop(0)
                end
            end
            hum:Move(Vector3.zero, false)
            hum.AutoRotate = false
            hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
            hum:SetStateEnabled(Enum.HumanoidStateType.Freefall, false)
            hum:ChangeState(Enum.HumanoidStateType.Physics)

            attachFlyMovers(hrp)

            flyConnection = RunService.RenderStepped:Connect(function()
                if not flyActive then return end
                -- Karakter yenilendiyse (MM2'de her turda olur) bu bağlantı eski karaktere aittir
                local curChar = LocalPlayer.Character
                local curHrp = curChar and curChar:FindFirstChild("HumanoidRootPart")
                if not curHrp or curHrp ~= hrp or not hrp.Parent then return end
                -- Oyun BodyVelocity/BodyGyro'yu silerse yeniden ekle
                if not flyBv or not flyBv.Parent or not flyBg or not flyBg.Parent then
                    attachFlyMovers(hrp)
                end
                local cam = workspace.CurrentCamera
                local moveDir = Vector3.zero
                if UserInputService:IsKeyDown(Enum.KeyCode.W) then
                    moveDir = moveDir + cam.CFrame.LookVector
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) then
                    moveDir = moveDir - cam.CFrame.LookVector
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) then
                    moveDir = moveDir - cam.CFrame.RightVector
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) then
                    moveDir = moveDir + cam.CFrame.RightVector
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                    moveDir = moveDir + Vector3.new(0, 1, 0)
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
                    moveDir = moveDir - Vector3.new(0, 1, 0)
                end
                flyBv.Velocity = moveDir * Settings.FlySpeed
                -- Klavye ile hareket ederken Humanoid'in koşu/yürüme animasyonu tetiklenmesin.
                if flyHumanoid and flyHumanoid.Parent then
                    flyHumanoid:Move(Vector3.zero, false)
                    local animator2 = flyHumanoid:FindFirstChildOfClass("Animator")
                    if animator2 then
                        for _, track in ipairs(animator2:GetPlayingAnimationTracks()) do
                            track:Stop(0)
                        end
                    end
                end

                -- Kamera hareket etse bile karakterin gövdesi dik ve sabit kalır.
                local look = cam.CFrame.LookVector
                local flatLook = Vector3.new(look.X, 0, look.Z)
                if flatLook.Magnitude > 0.001 then
                    flyBg.CFrame = CFrame.lookAt(hrp.Position, hrp.Position + flatLook.Unit)
                end
                if flyHumanoid and flyHumanoid.Parent and flyHumanoid:GetState() ~= Enum.HumanoidStateType.Physics then
                    flyHumanoid:ChangeState(Enum.HumanoidStateType.Physics)
                end
            end)
            if not silent then
                notify("Fly Aktif", "Uçuş modu açıldı! Tuş: " .. Settings.FlyKey.Name, 2)
            end
        else
            stopFlyMovers()
            if flyHumanoid and flyHumanoid.Parent then
                if flyOldAutoRotate ~= nil then flyHumanoid.AutoRotate = flyOldAutoRotate end
                if flyOldJumpingEnabled ~= nil then flyHumanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, flyOldJumpingEnabled) end
                if flyOldFreefallEnabled ~= nil then flyHumanoid:SetStateEnabled(Enum.HumanoidStateType.Freefall, flyOldFreefallEnabled) end
                if flyAnimateScript and flyAnimateScript.Parent and flyOldAnimateEnabled ~= nil then
                    flyAnimateScript.Enabled = flyOldAnimateEnabled
                end
                flyHumanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
            end
            flyHumanoid = nil
            flyAnimateScript, flyOldAnimateEnabled = nil, nil
            flyOldAutoRotate, flyOldJumpingEnabled, flyOldFreefallEnabled = nil, nil, nil
            if not silent then
                notify("Fly Kapandı", "Uçuş modu kapatıldı.", 2)
            end
        end
    end)
end

-- Karakter yenilenince (MM2'de her turda / ölünce) uçuş açıksa yeni karakterde yeniden başlat
bind(LocalPlayer.CharacterAdded, function(char)
    if not flyActive then return end
    task.spawn(function()
        local hrp = char:WaitForChild("HumanoidRootPart", 10)
        local hum = char:WaitForChild("Humanoid", 10)
        if not hrp or not hum or not alive or not flyActive then return end
        task.wait(0.6) -- oyunun doğuş ayarlarını bitirmesini bekle
        if flyActive and LocalPlayer.Character == char then
            flyHumanoid = nil -- yeni karakter: eski karakterin durum bilgisini sıfırla
            toggleFly(true, true)
        end
    end)
end)

local flyToggleObj = createToggle(FeaturesPage, "🛸  Fly (Uçma) Modu", false, function(v)
    toggleFly(v)
end)

do
    local row, st = baseRow(FeaturesPage, "TextButton", 42)
    rowLabel(row, "Fly Açma/Kapatma Tuşu")
    local keyText = new("TextLabel", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.new(0, 100, 0, 26),
        BackgroundTransparency = 1, Text = Settings.FlyKey.Name, Font = Enum.Font.GothamBold, TextSize = 13,
        TextColor3 = Color3.fromRGB(255, 65, 75), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 4,
    }, row)
    hoverFx(row, st)

    updateFlyKeyTextCallback = function(name)
        setText(keyText, name)
    end

    bind(row.MouseButton1Click, function()
        playClickSound()
        listeningFlyKey = true
        setText(keyText, "Tuşa basın...")
        notify("Tuş Bekleniyor", "Fly için yeni bir klavye tuşuna basın...", 3)
    end)
end

createSlider(FeaturesPage, "🚀  Fly Hızı", 10, 300, Settings.FlySpeed, function(v)
    Settings.FlySpeed = v
end, "")

bind(UserInputService.InputBegan, function(input, gpe)
    if not ready or listeningFlyKey or listeningForKey then return end
    -- MM2 gibi oyunlar tuşları kendi kısayollarına bağlayıp gpe=true döndürebilir.
    -- Bu yüzden yalnızca yazı kutusuna yazarken ya da Roblox menüsü açıkken yok sayılır.
    if gpe and UserInputService:GetFocusedTextBox() then return end
    if GuiService.MenuIsOpen then return end
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    if input.KeyCode == Settings.FlyKey then
        flyActive = not flyActive
        toggleFly(flyActive)
        flyToggleObj.Set(flyActive, true)
    end
end)

end

-- FPS BOOST VE ULTRA FPS MODLARI
-- Üç kademeli ortak FPS motoru (Özellikler: FPS Modu = 1, Ultra = 2 | Premium: FPS Artırıcı PRO = 3).
-- Kademe 3 diğer ikisinin hepsini zaten içerir; ayrıca açmaya gerek yoktur.
-- Yeni yüklenen her nesneye (harita değişimi dahil) anında uygulanır; kapatınca her şey eski haline döner.
do
    local FPSX = {flags = {fps = false, ultra = false, pro = false}, level = 0, cap = 360}
    Settings.FPSX = FPSX
    local saved = setmetatable({}, {__mode = "k"})       -- [nesne] = {özellik = eskiDeğer}
    local hooked = setmetatable({}, {__mode = "k"})
    local done = setmetatable({}, {__mode = "k"})
    local token, loopTok, addedConn, rootAddedConn = 0, 0, nil, nil
    local SMOOTH, NEON, FFIELD = Enum.Material.SmoothPlastic, Enum.Material.Neon, Enum.Material.ForceField
    local staleDarken = Lighting:FindFirstChild("EZRAGOX_Darken")
    if staleDarken then pcall(function() staleDarken:Destroy() end) end

    local function setp(o, prop, val)
        local ok, old = pcall(function() return o[prop] end)
        if not ok or old == val then return end
        local r = saved[o]
        if not r then r = {} saved[o] = r end
        if r[prop] == nil then r[prop] = old end
        pcall(function() o[prop] = val end)
    end

    -- 1 = kendi karakterim / EZRAGOX nesnesi (aura vb. → dokunma), 2 = başka oyuncunun karakteri, 0 = harita
    local function classify(o)
        local ch = LocalPlayer.Character
        local p, coin = o.Parent, false
        while p and p ~= workspace do
            if p == ch or string.sub(p.Name, 1, 8) == "EZRAGOX_" then return 1, false end
            if p.Name == "CoinContainer" then coin = true end
            if p:IsA("Model") and Players:GetPlayerFromCharacter(p) then return 2, false end
            p = p.Parent
        end
        return 0, coin
    end

    local function looksLikeCharacter(m)
        return m:FindFirstChild("Head") ~= nil or m:FindFirstChild("HumanoidRootPart") ~= nil
            or m:FindFirstChild("UpperTorso") ~= nil or m:FindFirstChild("Torso") ~= nil
    end

    local seenAlive = setmetatable({}, {__mode = "k"})   -- bir kez canlı görülen karakter modelleri

    local function isCorpse(m)
        if not m:IsA("Model") or m == LocalPlayer.Character then return false end
        local p = Players:FindFirstChild(m.Name)
        local hum = m:FindFirstChildOfClass("Humanoid")
        if hum then
            local okS, st = pcall(function() return hum:GetState() end)
            if hum.Health <= 0 or (okS and st == Enum.HumanoidStateType.Dead) then return true end
            seenAlive[m] = true
            return p ~= nil and p ~= LocalPlayer and p.Character ~= nil and p.Character ~= m
        end
        -- MM2 gibi oyunlar ölünce Humanoid'i silebilir: canlıyken görülmüş ama artık Humanoid'i olmayan karakter = ceset
        if seenAlive[m] and looksLikeCharacter(m) then return true end
        -- Humanoid'i silinmiş eski karakter: oyuncunun adını taşıyan ama artık onun karakteri olmayan model
        return p ~= nil and p ~= LocalPlayer and p.Character ~= m and looksLikeCharacter(m)
    end

    local corpses = setmetatable({}, {__mode = "k"})   -- gizlenen cesetler (yeni parçalar için periyodik yeniden taranır)
    local keepParent = setmetatable({}, {__mode = "k"}) -- haritanın süs cesetleri: sadece görünmez yapılır, modelden çıkarılmaz

    local function stripOne(d)
        if d:IsA("BasePart") then
            setp(d, "LocalTransparencyModifier", 1)
            setp(d, "Transparency", 1)
            setp(d, "CanCollide", false)
            setp(d, "CanTouch", false)
            setp(d, "CastShadow", false)
        elseif d:IsA("Decal") or d:IsA("Texture") then
            setp(d, "Transparency", 1)
        elseif d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Beam") or d:IsA("Fire")
            or d:IsA("Smoke") or d:IsA("Sparkles") or d:IsA("Highlight") then
            setp(d, "Enabled", false)
        elseif d:IsA("BillboardGui") or d:IsA("SurfaceGui") then
            setp(d, "Enabled", false)
        elseif d:IsA("Sound") then
            setp(d, "Volume", 0)
        end
    end

    local function stripParts(m)
        for _, d in ipairs(m:GetDescendants()) do
            pcall(stripOne, d)
        end
    end

    FPSX.removeCorpses = true   -- true: yerdeki ceset modeli yalnızca senin istemcinde tamamen kaldırılır (sunucuya etkisi yok)

    local function strip(m)
        if not m or not m.Parent then return end
        corpses[m] = true
        stripParts(m)
        -- Parçaları gizlemek bir şekilde yetmezse (oyun şeffaflığı geri çeviriyorsa) modeli bu istemciden tamamen çıkar.
        if FPSX.removeCorpses and FPSX.level >= 3 and m:IsA("Model") and not keepParent[m] then
            task.defer(function()
                if m.Parent and FPSX.level >= 3 then pcall(function() m.Parent = nil end) end
            end)
        end
        local hum = m:FindFirstChildOfClass("Humanoid")
        if hum then setp(hum, "DisplayDistanceType", Enum.HumanoidDisplayDistanceType.None) end
        if not done[m] then
            done[m] = true
            -- Ceset gizlendikten sonra eklenen parçalar (aksesuar, ragdoll parçası vb.) da anında gizlenir
            m.DescendantAdded:Connect(function(d)
                if FPSX.level >= 3 and corpses[m] then
                    task.defer(function() if d.Parent then pcall(stripOne, d) end end)
                end
            end)
        end
    end

    local function hasAccessoryAncestor(o)
        local p = o and o.Parent
        while p and p ~= workspace do
            if p:IsA("Accessory") then return true end
            if p:IsA("Model") and Players:GetPlayerFromCharacter(p) then return false end
            p = p.Parent
        end
        return false
    end

    local function stopOtherAnimations(animator)
        pcall(function()
            for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                track:Stop(0)
            end
        end)
    end

    -- İNSAN İSKELETİ TARAYICISI: ceset oyuncunun karakteri değil, ayrı bir kopya / dağınık parçalar olabilir.
    -- Adı ne olursa olsun, içinde en az 3 vücut parçası bulunan ve canlı Humanoid'i olmayan her yapı ceset sayılır.
    local BODY = {
        Head = true, Torso = true, UpperTorso = true, LowerTorso = true, HumanoidRootPart = true,
        ["Left Arm"] = true, ["Right Arm"] = true, ["Left Leg"] = true, ["Right Leg"] = true,
        LeftUpperArm = true, RightUpperArm = true, LeftLowerArm = true, RightLowerArm = true,
        LeftHand = true, RightHand = true, LeftUpperLeg = true, RightUpperLeg = true,
        LeftLowerLeg = true, RightLowerLeg = true, LeftFoot = true, RightFoot = true,
    }

    local pendingRig = setmetatable({}, {__mode = "k"})
    local function checkRig(part)
        local rig = part.Parent
        if not rig or rig == workspace or corpses[rig] or pendingRig[rig] then return end
        local ch = LocalPlayer.Character
        if ch and (rig == ch or part:IsDescendantOf(ch)) then return end
        if string.sub(rig.Name, 1, 8) == "EZRAGOX_" then return end
        local n = 0
        for _, c in ipairs(rig:GetChildren()) do
            if BODY[c.Name] and c:IsA("BasePart") then n = n + 1 end
        end
        if n < 3 then return end
        local hum = rig:FindFirstChildOfClass("Humanoid")
        if hum then
            if hum.Health > 0 then
                -- Haritadaki süs cesedi (ör. Spaceship haritasındaki Raggy / Alien): HP 100 görünür ama
                -- gövdesi yere sabitlenmiştir (Anchored) ve hiçbir oyuncuya ait değildir.
                local root = rig:FindFirstChild("HumanoidRootPart") or (rig:IsA("Model") and rig.PrimaryPart) or nil
                if root and root:IsA("BasePart") and root.Anchored then
                    pendingRig[rig] = true
                    task.delay(1, function()
                        pendingRig[rig] = nil
                        if FPSX.level < 3 or not rig.Parent or corpses[rig] then return end
                        if rig:IsA("Model") and Players:GetPlayerFromCharacter(rig) then return end
                        if Players:FindFirstChild(rig.Name) then return end
                        if not root.Parent or not root.Anchored then return end
                        keepParent[rig] = true
                        pcall(strip, rig)
                    end)
                end
                return        -- canlı oyuncu / canlı NPC
            end
            strip(rig)
            return
        end
        -- Humanoid yok: yeni doğan oyuncunun karakteri yüklenirken olabilir; kısa süre bekleyip tekrar bak.
        pendingRig[rig] = true
        task.delay(1, function()
            pendingRig[rig] = nil
            if FPSX.level < 3 or not rig.Parent or corpses[rig] then return end
            local c2 = LocalPlayer.Character
            if c2 and (rig == c2 or part:IsDescendantOf(c2)) then return end
            if rig:FindFirstChildOfClass("Humanoid") then return end
            if rig:IsA("Model") and Players:GetPlayerFromCharacter(rig) and not seenAlive[rig] then return end
            pcall(strip, rig)
        end)
    end

    -- YATAN KARAKTER ALGILAMA: Humanoid'i "canlı" görünse bile yerde hareketsiz yatan (ayakta olmayan)
    -- başka oyuncu karakteri ceset sayılır; sadece görüntü gizlenir, ayağa kalkarsa geri gelir.
    local softHidden, lyingSince, standSince = {}, {}, {}

    local function hideBody(c)
        for _, d in ipairs(c:GetDescendants()) do pcall(stripOne, d) end
    end

    local function showBody(c)
        for _, d in ipairs(c:GetDescendants()) do
            local r = saved[d]
            if r then
                for prop, v in pairs(r) do
                    pcall(function() d[prop] = v end)
                    r[prop] = nil
                end
                saved[d] = nil
                -- aksesuarlar PRO modunda gizli kalmaya devam eder
                if d:IsA("BasePart") and hasAccessoryAncestor(d) then setp(d, "LocalTransparencyModifier", 1) end
            end
        end
    end

    local function lyingCheck()
        local now = os.clock()
        for _, p in ipairs(Players:GetPlayers()) do
            local c = p.Character
            if p ~= LocalPlayer and c and c ~= LocalPlayer.Character and c.Parent then
                local tor = c:FindFirstChild("UpperTorso") or c:FindFirstChild("Torso") or c:FindFirstChild("HumanoidRootPart")
                if tor and tor:IsA("BasePart") then
                    local lying = tor.CFrame.UpVector.Y < 0.4 and tor.AssemblyLinearVelocity.Magnitude < 4
                    if lying then
                        standSince[c] = nil
                        lyingSince[c] = lyingSince[c] or now
                        if now - lyingSince[c] > 1 and not softHidden[c] and not corpses[c] then
                            softHidden[c] = true
                            hideBody(c)
                        end
                    elseif softHidden[c] then
                        standSince[c] = standSince[c] or now
                        if now - standSince[c] > 1 then
                            softHidden[c], lyingSince[c], standSince[c] = nil, nil, nil
                            showBody(c)
                        end
                    else
                        lyingSince[c] = nil
                    end
                end
            end
        end
        for c in pairs(softHidden) do
            if not c.Parent then softHidden[c] = nil end
        end
    end
    FPSX.lyingCheck = lyingCheck

    local function apply(o, lvl)
        if lvl < 1 then return end
        if lvl >= 3 and BODY[o.Name] and o:IsA("BasePart") then pcall(checkRig, o) end
        -- Ölen oyuncuyu ölür ölmez gizle (kademe 3)
        if lvl >= 3 and o:IsA("Humanoid") then
            local m = o.Parent
            if m and m ~= LocalPlayer.Character then
                -- Tarama sırasında zaten ölü bulunan karakter (klasör içinde olsa bile) hemen gizlenir
                if o.Health <= 0 then pcall(strip, m) end
                if not hooked[o] then
                    hooked[o] = true
                    o.Died:Connect(function()
                        task.delay(0.05, function()
                            if FPSX.level >= 3 and m and m.Parent then pcall(strip, m) end
                        end)
                    end)
                end
            end
        end
        local kind, coin = classify(o)
        if kind == 1 then return end
        if o:IsA("Animator") and kind == 2 then
            if lvl >= 3 then stopOtherAnimations(o) end
        elseif o:IsA("BasePart") then
            if kind == 2 then
                -- Diğer oyuncuların aksesuarları yalnızca bu istemcide gizlenir.
                if lvl >= 3 and hasAccessoryAncestor(o) then
                    setp(o, "LocalTransparencyModifier", 1)
                end
                return
            end
            setp(o, "CastShadow", false)
            if lvl >= 2 then
                local m = o.Material
                if m ~= NEON and m ~= FFIELD and m ~= SMOOTH then setp(o, "Material", SMOOTH) end
                if o.ClassName == "MeshPart" then setp(o, "RenderFidelity", Enum.RenderFidelity.Performance) end
            end
            if lvl >= 3 then
                setp(o, "Reflectance", 0)
                if not coin and o.ClassName == "MeshPart" then setp(o, "TextureID", "") end
            end
        elseif o:IsA("ParticleEmitter") or o:IsA("Trail") or o:IsA("Fire") or o:IsA("Smoke") or o:IsA("Sparkles") then
            if lvl >= 2 then setp(o, "Enabled", false) end
        elseif o:IsA("Beam") then
            if lvl >= 3 then setp(o, "Enabled", false) end
        elseif o:IsA("Decal") or o:IsA("Texture") then
            if lvl >= 2 and kind == 0 then setp(o, "Transparency", 1) end
        elseif o:IsA("SpecialMesh") then
            if lvl >= 3 and kind == 0 then setp(o, "TextureId", "") end
        elseif o:IsA("SurfaceAppearance") then
            if lvl >= 3 and kind == 0 then
                setp(o, "ColorMap", "")
                setp(o, "MetalnessMap", "")
                setp(o, "NormalMap", "")
                setp(o, "RoughnessMap", "")
            end
        elseif o:IsA("PointLight") or o:IsA("SpotLight") or o:IsA("SurfaceLight") then
            setp(o, "Shadows", false)
            if lvl >= 3 then setp(o, "Enabled", false) end
        elseif lvl >= 3 and coin then
            -- Yalnızca coin üstündeki görsel arayüzler kapatılır. Coin script'lerine DOKUNULMAZ:
            -- toplama (dokununca alma) mantığı onlarda olabilir, kapatmak coin almayı bozuyordu.
            if o:IsA("BillboardGui") or o:IsA("SurfaceGui") then
                setp(o, "Enabled", false)
            end
        end
    end

    -- Premium FPS PRO: Haritayi karartan renk duzeltmesi kaldirildi.
    -- Normal Lighting parlakligi ve renkleri korunur.
    local darkenEffect = nil
    local function syncDarken(lvl)
        local existing = Lighting:FindFirstChild("EZRAGOX_Darken")
        if existing then
            pcall(function() existing:Destroy() end)
        end
        if darkenEffect then
            pcall(function() darkenEffect:Destroy() end)
            darkenEffect = nil
        end
    end

    local function applyGlobal(lvl)
        if lvl < 1 then return end
        syncDarken(lvl)
        setp(Lighting, "GlobalShadows", false)
        for _, c in ipairs(Lighting:GetChildren()) do
            if string.sub(c.Name, 1, 8) ~= "EZRAGOX_" then
                if c:IsA("PostEffect") then
                    setp(c, "Enabled", false)
                elseif lvl >= 3 and c:IsA("Atmosphere") then
                    setp(c, "Density", 0)
                    setp(c, "Haze", 0)
                end
            end
        end
        if lvl >= 2 then
            setp(Lighting, "EnvironmentSpecularScale", 0)
            setp(Lighting, "EnvironmentDiffuseScale", 0)
        end
        if lvl >= 3 then
            local t = workspace:FindFirstChildOfClass("Terrain")
            if t then
                setp(t, "WaterWaveSize", 0)
                setp(t, "WaterWaveSpeed", 0)
                setp(t, "WaterReflectance", 0)
                setp(t, "Decoration", false)
            end
            pcall(function()
                local r = settings().Rendering
                setp(r, "QualityLevel", Enum.QualityLevel.Level01)
                setp(r, "MeshPartDetailLevel", Enum.MeshPartDetailLevel.Level04)
            end)
            if setfpscap then pcall(setfpscap, FPSX.cap) end
        end
    end

    -- Zaman bütçeli tarama: kare başına ~6 ms → büyük haritada bile takılmadan ve hızlı biter
    local function sweep(my, lvl)
        local list = workspace:GetDescendants()
        local t0 = os.clock()
        for i = 1, #list do
            if my ~= token or not alive then return end
            pcall(apply, list[i], lvl)
            if os.clock() - t0 > 0.006 then task.wait() t0 = os.clock() end
        end
    end

    local function restoreAll(my)
        local t0 = os.clock()
        for o, r in pairs(saved) do
            if my and my ~= token then return end
            for prop, v in pairs(r) do
                pcall(function() o[prop] = v end)
            end
            saved[o] = nil
            if os.clock() - t0 > 0.006 then task.wait() t0 = os.clock() end
        end
        -- FPS modları kapanırken 60 FPS sınırı dayatma; destekleniyorsa sınırı serbest bırak.
        if setfpscap and FPSX.level < 3 then pcall(setfpscap, 9999) end
        if FPSX.level == 0 then
            local existing = Lighting:FindFirstChild("EZRAGOX_Darken")
            if existing then pcall(function() existing:Destroy() end) end
            if darkenEffect then
                pcall(function() darkenEffect:Destroy() end)
                darkenEffect = nil
            end
        end
    end

    function FPSX.setCap(v)
        FPSX.cap = math.floor(v)
        if FPSX.level >= 3 and setfpscap then pcall(setfpscap, FPSX.cap) end
    end

    function FPSX.refresh()
        local lvl = FPSX.flags.pro and 3 or (FPSX.flags.ultra and 2 or (FPSX.flags.fps and 1 or 0))
        if lvl == FPSX.level then return end
        local old = FPSX.level
        FPSX.level = lvl
        token = token + 1
        loopTok = loopTok + 1
        local my, myLoop = token, loopTok
        if addedConn then addedConn:Disconnect() addedConn = nil end
        if rootAddedConn then rootAddedConn:Disconnect() rootAddedConn = nil end
        if lvl == 0 then
            task.spawn(restoreAll, my)
            return
        end
        -- Yeni harita kökü Workspace'e eklendiğinde, içindeki mevcut nesneleri
        -- beklemeden tara. DescendantAdded ise sonradan gelen parçaları anında işler.
        local function applyNewObject(o)
            local currentLevel = FPSX.level
            if currentLevel <= 0 or not o or not o.Parent then return end
            task.defer(function()
                if FPSX.level == currentLevel and o.Parent then
                    pcall(apply, o, currentLevel)
                    -- Harita modeli tek seferde eklendiyse içindeki hazır nesneleri de tara.
                    if o:IsA("Model") or o:IsA("Folder") then
                        for _, child in ipairs(o:GetDescendants()) do
                            if FPSX.level ~= currentLevel then return end
                            pcall(apply, child, currentLevel)
                        end
                    end
                end
            end)
        end
        addedConn = workspace.DescendantAdded:Connect(applyNewObject)
        rootAddedConn = workspace.ChildAdded:Connect(applyNewObject)
        task.spawn(function()
            if lvl < old then restoreAll(my) end
            if my ~= token then return end
            applyGlobal(lvl)
            sweep(my, lvl)
        end)
        -- Bakım döngüsü: oyun ayarları geri çevirirse yeniden uygular, kademe 3'te ceset gizleme + coin toplama
        task.spawn(function()
            local lastFull, lastCorpseScan, lastCorpseRefresh = os.clock(), 0, 0
            while alive and myLoop == loopTok do
                if lvl >= 3 then
                    -- Ölü oyuncuları / ceset modellerini ara: her karede DEĞİL, saniyede birkaç kez yeter.
                    -- (Önceki sürümde bu her 0.15 sn'de bir, klasör içlerine de bakarak çalışıyordu; büyük
                    -- haritalarda bu sürekli tarama performans düşüşüne (kasmaya) yol açıyordu.)
                    if os.clock() - lastCorpseScan > 0.5 then
                        lastCorpseScan = os.clock()
                        pcall(function()
                            for _, m in ipairs(workspace:GetChildren()) do
                                if isCorpse(m) then
                                    strip(m)
                                elseif m:IsA("Folder") or (m:IsA("Model") and not looksLikeCharacter(m)) then
                                    -- Cesetler bir klasörün / haritanın bir seviye içinde de durabilir (MM2 vb.)
                                    for _, sub in ipairs(m:GetChildren()) do
                                        if sub:IsA("Model") and isCorpse(sub) then strip(sub) end
                                    end
                                end
                            end
                            -- Karakteri Workspace kökünde olmasa bile (klasör içi vb.) ölü oyuncuları gizle
                            for _, p in ipairs(Players:GetPlayers()) do
                                local c = p.Character
                                if p ~= LocalPlayer and c and c ~= LocalPlayer.Character then
                                    if isCorpse(c) then strip(c) end
                                end
                            end
                        end)
                    end
                    lyingCheck()
                    -- Gizlenmiş cesetlerde sonradan beliren parçalar: zaten strip() her cesede kendi
                    -- DescendantAdded dinleyicisini takıyor, bu yüzden burada yalnızca seyrek bir
                    -- güvenlik taraması yeterli (tekrar tekrar tüm cesetleri taramak gereksiz yük bindirir).
                    if os.clock() - lastCorpseRefresh > 3 then
                        lastCorpseRefresh = os.clock()
                        pcall(function()
                            for m in pairs(corpses) do
                                if m.Parent then stripParts(m) else corpses[m] = nil end
                            end
                        end)
                    end
                end
                applyGlobal(lvl)
                if os.clock() - lastFull > 20 then
                    lastFull = os.clock()
                    sweep(my, lvl)
                end
                task.wait(0.2)
            end
        end)
    end

    task.spawn(function()
        while alive do task.wait(1) end
        FPSX.flags.fps, FPSX.flags.ultra, FPSX.flags.pro = false, false, false
        FPSX.level = 0
        if addedConn then addedConn:Disconnect() end
        if rootAddedConn then rootAddedConn:Disconnect() end
        restoreAll()
    end)
end

createSection(FeaturesPage, "PERFORMANS VE FPS MODLARI")

createToggle(FeaturesPage, "📈  FPS Modu (Optimizasyon)", false, function(v)
    Settings.FPSX.flags.fps = v
    Settings.FPSX.refresh()
    notify("FPS Modu", v and "FPS Optimizasyonu aktif! Gölgeler ve efektler kapatıldı." or "Normal ayarlara dönüldü.", 3)
end)

createToggle(FeaturesPage, "⚡  Ultra FPS Modu (Maksimum Performans)", false, function(v)
    ultraFpsDisplayBoost = v
    Settings.FPSX.flags.ultra = v
    Settings.FPSX.refresh()
    notify("Ultra FPS", v and "Ultra FPS Modu aktif! Donanım yükü minimuma indirildi." or "Ultra mod kapatıldı.", 3)
end)

-- SUNUCU
createSection(FeaturesPage, "SUNUCU")

createButton(FeaturesPage, "🔄  Sunucudan Çık ve Tekrar Gir (Rejoin)", function()
    if Settings.RejoinBusy then return end
    Settings.RejoinBusy = true
    notify("Rejoin", "Sunucudan çıkılıp aynı sunucuya tekrar giriliyor...", 3)
    local ok = pcall(function()
        local ts = game:GetService("TeleportService")
        if #Players:GetPlayers() <= 1 then
            -- Sunucuda tek başınaysan aynı sunucu kalmaz; yeni bir sunucuya girer
            ts:Teleport(game.PlaceId, LocalPlayer)
        else
            ts:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
        end
    end)
    if not ok then
        notify("Rejoin", "Yeniden giriş başlatılamadı.", 3)
    end
    task.delay(8, function() Settings.RejoinBusy = false end)
end)

-- ESP (DUVAR ARKASI GÖRÜŞ)
createSection(FeaturesPage, "ESP (DUVAR ARKASI GÖRÜŞ)")
do
    local espOn = false
    local espData = {}      -- [Player] = {hl, gui, name, dist, hue}
    local espFolder = nil
    local espTargetOnly = false
    local espTarget = nil   -- Sadece-seçili modunda gösterilecek oyuncu
    local targetBox = nil   -- Hedef yazma kutusu (aşağıda oluşturulur)

    -- Seçilebilir renkler; "RGB" = akan gökkuşağı renkleri
    local ESP_COLORS = {
        {name = "Yeşil",   color = Color3.fromRGB(0, 255, 70)},
        {name = "Kırmızı", color = Color3.fromRGB(255, 45, 45)},
        {name = "Mavi",    color = Color3.fromRGB(45, 130, 255)},
        {name = "Sarı",    color = Color3.fromRGB(255, 230, 40)},
        {name = "Turuncu", color = Color3.fromRGB(255, 140, 30)},
        {name = "Mor",     color = Color3.fromRGB(175, 75, 255)},
        {name = "Pembe",   color = Color3.fromRGB(255, 95, 205)},
        {name = "Beyaz",   color = Color3.fromRGB(255, 255, 255)},
        {name = "RGB",     rainbow = true},
    }
    local function loadIdx(key, default)
        local v = Settings.SliderValues[key]
        if type(v) == "number" and ESP_COLORS[v] then return v end
        return default
    end
    local fillIdx = loadIdx("__ESP_FILL", 1)                 -- çerçeve/dolgu rengi (varsayılan yeşil)
    local nameIdx = loadIdx("__ESP_NAME", #ESP_COLORS)       -- isim rengi (varsayılan RGB)

    local function getEspFolder()
        if espFolder and espFolder.Parent then return espFolder end
        espFolder = Instance.new("Folder")
        espFolder.Name = "EZRAGOX_ESP"
        espFolder.Parent = ScreenGui.Parent or CoreGui
        return espFolder
    end

    local function removeEsp(plr)
        local d = espData[plr]
        if not d then return end
        espData[plr] = nil
        pcall(function() d.hl:Destroy() end)
        pcall(function() d.gui:Destroy() end)
    end

    -- Seçili renk ayarlarını bir oyuncunun ESP'sine uygula
    local function paint(d, t)
        local fc = ESP_COLORS[fillIdx]
        if fc.rainbow then
            local col = Color3.fromHSV((t + d.hue) % 1, 0.9, 1)
            d.hl.FillColor = col
            d.hl.OutlineColor = col:Lerp(Color3.new(1, 1, 1), 0.5)
        else
            d.hl.FillColor = fc.color
            d.hl.OutlineColor = fc.color:Lerp(Color3.new(1, 1, 1), 0.55)
        end
        local nc = ESP_COLORS[nameIdx]
        d.name.TextColor3 = nc.rainbow and Color3.fromHSV((t + d.hue) % 1, 0.85, 1) or nc.color
    end

    local function repaintAll()
        local t = os.clock() * 0.25
        for _, d in pairs(espData) do pcall(paint, d, t) end
    end

    local function shouldShow(plr)
        if plr == LocalPlayer then return false end
        if espTargetOnly then return plr == espTarget end
        return true
    end

    local function buildEsp(plr)
        removeEsp(plr)
        if not shouldShow(plr) then return end
        local char = plr.Character
        if not char then return end
        local head = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
        if not head then return end
        local folder = getEspFolder()

        -- AlwaysOnTop sayesinde duvar arkasından da görünür
        local hl = new("Highlight", {
            Name = "ESP_" .. plr.Name,
            Adornee = char,
            FillColor = Color3.fromRGB(0, 255, 70),
            OutlineColor = Color3.fromRGB(150, 255, 170),
            FillTransparency = 0.45,
            OutlineTransparency = 0,
            DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
        }, folder)

        -- Karakterin üstünde isim + mesafe
        local gui = new("BillboardGui", {
            Name = "ESPName_" .. plr.Name,
            Adornee = head,
            AlwaysOnTop = true,
            Size = UDim2.new(0, 220, 0, 44),
            StudsOffset = Vector3.new(0, 2.6, 0),
            ResetOnSpawn = false,
        }, folder)
        local nameLbl = new("TextLabel", {
            Size = UDim2.new(1, 0, 0.6, 0),
            BackgroundTransparency = 1,
            Text = plr.DisplayName,
            Font = Enum.Font.GothamBold,
            TextSize = 18,
            TextColor3 = Color3.new(1, 1, 1),
            TextStrokeTransparency = 0,
            TextStrokeColor3 = Color3.new(0, 0, 0),
        }, gui)
        local distLbl = new("TextLabel", {
            Position = UDim2.new(0, 0, 0.6, 0),
            Size = UDim2.new(1, 0, 0.4, 0),
            BackgroundTransparency = 1,
            Text = "",
            Font = Enum.Font.GothamMedium,
            TextSize = 13,
            TextColor3 = Color3.fromRGB(235, 255, 240),
            TextStrokeTransparency = 0.2,
            TextStrokeColor3 = Color3.new(0, 0, 0),
        }, gui)

        espData[plr] = {hl = hl, gui = gui, name = nameLbl, dist = distLbl, hue = (plr.UserId % 100) / 100}
        pcall(paint, espData[plr], os.clock() * 0.25)
    end

    local function refreshEsp()
        local list = {}
        for p in pairs(espData) do list[#list + 1] = p end
        for _, p in ipairs(list) do removeEsp(p) end
        if not espOn then return end
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Character then pcall(buildEsp, p) end
        end
    end

    local function hookEspPlayer(plr)
        if plr == LocalPlayer then return end
        bind(plr.CharacterAdded, function(char)
            if not espOn or not shouldShow(plr) then return end
            char:WaitForChild("Head", 5)
            if espOn and plr.Character == char then
                pcall(buildEsp, plr)
            end
        end)
        bind(plr.CharacterRemoving, function() removeEsp(plr) end)
    end

    for _, p in ipairs(Players:GetPlayers()) do hookEspPlayer(p) end
    bind(Players.PlayerAdded, function(p)
        hookEspPlayer(p)
        if espOn and p.Character then pcall(buildEsp, p) end
    end)
    bind(Players.PlayerRemoving, function(p)
        removeEsp(p)
        if p == espTarget then
            espTarget = nil
            if targetBox then targetBox.Text = "" end
            if espTargetOnly then notify("ESP Hedefi", "Hedef oyuncu oyundan çıktı.", 3) end
        end
    end)

    -- Her karede: RGB seçiliyse renkler akar, mesafe güncellenir
    local espDistAcc = 0
    bind(RunService.RenderStepped, function(dt)
        if not espOn then return end
        local t = os.clock() * 0.25
        local anyRainbow = ESP_COLORS[fillIdx].rainbow or ESP_COLORS[nameIdx].rainbow
        -- Mesafe yazısı saniyede ~12 kez ve yalnızca değer değişince güncellenir (renkler her karede akar)
        espDistAcc = espDistAcc + (dt or 0)
        local doDist = espDistAcc >= 0.08
        if doDist then espDistAcc = 0 end
        local cam = doDist and workspace.CurrentCamera or nil
        for plr, d in pairs(espData) do
            if anyRainbow then paint(d, t) end
            if doDist then
                local head = d.gui.Adornee
                if cam and head and head.Parent then
                    local txt = math.floor((cam.CFrame.Position - head.Position).Magnitude + 0.5) .. " m"
                    if d.lastDist ~= txt then
                        d.lastDist = txt
                        setText(d.dist, txt)
                    end
                end
            end
        end
    end)

    -- Renk seçici satır: yan yana renk kutucukları, sonuncusu RGB
    local function createColorRow(title, getIdx, onPick)
        local row = baseRow(FeaturesPage, "Frame", 66)
        rowLabel(row, title).Position = UDim2.new(0, 14, 0, 8)
        local valueLabel = new("TextLabel", {
            Size = UDim2.new(0, 90, 0, 20), Position = UDim2.new(1, -104, 0, 8), BackgroundTransparency = 1,
            Text = ESP_COLORS[getIdx()].name, Font = Enum.Font.GothamBold, TextSize = 13,
            TextColor3 = Color3.fromRGB(255, 65, 75), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 4,
        }, row)
        local holder = new("Frame", {
            Position = UDim2.new(0, 14, 0, 34), Size = UDim2.new(1, -28, 0, 26),
            BackgroundTransparency = 1, ZIndex = 4,
        }, row)
        new("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6),
            SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center,
        }, holder)

        local swatches = {}
        local function refresh()
            local sel = getIdx()
            for i, s in ipairs(swatches) do
                tween(s, 0.15, {
                    Transparency = (i == sel) and 0 or 0.75,
                    Thickness = (i == sel) and 2.5 or 1,
                })
            end
            setText(valueLabel, ESP_COLORS[sel].name)
        end
        for i, c in ipairs(ESP_COLORS) do
            local b = new("TextButton", {
                LayoutOrder = i, Size = UDim2.new(0, 26, 0, 26),
                BackgroundColor3 = c.color or Color3.new(1, 1, 1),
                AutoButtonColor = false, Text = "", ZIndex = 5,
            }, holder)
            pill(b)
            if c.rainbow then
                new("UIGradient", {
                    Rotation = 45,
                    Color = ColorSequence.new({
                        ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 0, 0)),
                        ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 255, 0)),
                        ColorSequenceKeypoint.new(0.34, Color3.fromRGB(0, 255, 0)),
                        ColorSequenceKeypoint.new(0.50, Color3.fromRGB(0, 255, 255)),
                        ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0, 0, 255)),
                        ColorSequenceKeypoint.new(0.84, Color3.fromRGB(255, 0, 255)),
                        ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 0, 0)),
                    }),
                }, b)
            end
            swatches[i] = stroke(b, 1, Color3.new(1, 1, 1), 0.75)
            bind(b.MouseButton1Click, function()
                playClickSound()
                onPick(i)
                refresh()
            end)
        end
        refresh()
    end

    createToggle(FeaturesPage, "👁️  ESP (Duvar Arkası Görüş)", false, function(v)
        espOn = v
        refreshEsp()
        if v then
            if espTargetOnly then
                notify("ESP Aktif", "Sadece seçili oyuncu duvar arkasından görünüyor!", 3)
            else
                notify("ESP Aktif", "Oyuncular duvar arkasından görünüyor!", 3)
            end
        else
            notify("ESP Kapandı", "Oyuncu işaretleri kaldırıldı.", 2)
        end
    end)

    createColorRow("🎨  Çerçeve Rengi", function() return fillIdx end, function(i)
        fillIdx = i
        Settings.SliderValues["__ESP_FILL"] = i
        saveConfig()
        repaintAll()
    end)

    createColorRow("🔤  İsim Rengi", function() return nameIdx end, function(i)
        nameIdx = i
        Settings.SliderValues["__ESP_NAME"] = i
        saveConfig()
        repaintAll()
    end)

    -- Hedef oyuncu seçme (yalnızca ESP için)
    local targetRow = baseRow(FeaturesPage, "Frame", 48)
    rowLabel(targetRow, "🎯  ESP Hedefi")
    targetBox = new("TextBox", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -12, 0.5, 0),
        Size = UDim2.new(0, 180, 0, 32),
        BackgroundColor3 = Color3.fromRGB(28, 34, 54),
        Text = "",
        PlaceholderText = "İsim yaz (örn: hasan)",
        PlaceholderColor3 = Color3.fromRGB(120, 134, 170),
        TextColor3 = Color3.fromRGB(220, 230, 245),
        TextSize = 12,
        Font = Enum.Font.GothamBold,
        ClearTextOnFocus = false,
        ZIndex = 4,
    }, targetRow)
    corner(targetBox, 8)
    stroke(targetBox, 1, Color3.fromRGB(55, 65, 95), 0.3)

    local targetList = new("ScrollingFrame", {
        LayoutOrder = nextOrder(FeaturesPage),
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundColor3 = Color3.fromRGB(15, 18, 28),
        BackgroundTransparency = 0.05,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Visible = false,
        ZIndex = 20,
    }, FeaturesPage)
    corner(targetList, 10)
    stroke(targetList, 1, Color3.fromRGB(60, 75, 110), 0.2)
    new("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4)}, targetList)
    new("UIPadding", {PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6)}, targetList)

    local suppressBox = false
    local function setBoxText(txt)
        suppressBox = true
        targetBox.Text = txt
        suppressBox = false
    end
    Settings.PlayerPreviewBind(targetList)
    local function hideTargetList()
        targetList.Visible = false
        targetList.Size = UDim2.new(1, 0, 0, 0)
    end
    local function nameMatches(plr, filter)
        if plr == LocalPlayer then return false end
        filter = string.lower(filter or "")
        if filter == "" then return true end
        return string.find(string.lower(plr.Name), filter, 1, true) ~= nil
            or string.find(string.lower(plr.DisplayName), filter, 1, true) ~= nil
    end

    local onlyToggle
    local function selectTarget(plr)
        espTarget = plr
        setBoxText(plr.Name)
        pcall(function() targetBox:ReleaseFocus() end)
        hideTargetList()
        notify("ESP Hedefi", plr.DisplayName .. " seçildi.", 2)
        if espTargetOnly then refreshEsp() end
    end
    local function clearTarget()
        espTarget = nil
        setBoxText("")
        hideTargetList()
        if espTargetOnly then refreshEsp() end
    end

    local function updateTargetList(filterText)
        Settings.PlayerPreview(nil)
        for _, ch in ipairs(targetList:GetChildren()) do
            if ch:IsA("TextButton") then ch:Destroy() end
        end
        local count = 0
        for _, plr in ipairs(Players:GetPlayers()) do
            if nameMatches(plr, filterText) then
                count = count + 1
                local pBtn = new("TextButton", {
                    Size = UDim2.new(1, 0, 0, 36),
                    BackgroundColor3 = Color3.fromRGB(22, 27, 42),
                    BackgroundTransparency = 0.2,
                    AutoButtonColor = false,
                    Text = "",
                    ZIndex = 21,
                }, targetList)
                corner(pBtn, 8)
                ctaFx(pBtn, {radius = 8, colors = false})
                pBtn.MouseEnter:Connect(function()
                    tween(pBtn, 0.12, {BackgroundTransparency = 0})
                    Settings.PlayerPreview(plr)
                end)
                pBtn.MouseLeave:Connect(function()
                    tween(pBtn, 0.18, {BackgroundTransparency = 0.2})
                    Settings.PlayerPreview(nil)
                end)

                local avImg = new("ImageLabel", {
                    Position = UDim2.new(0, 4, 0, 2), Size = UDim2.new(0, 32, 0, 32),
                    BackgroundTransparency = 1, ZIndex = 22,
                }, pBtn)
                pill(avImg)
                task.spawn(function()
                    pcall(function()
                        avImg.Image = Players:GetUserThumbnailAsync(plr.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
                    end)
                end)
                new("TextLabel", {
                    Position = UDim2.new(0, 42, 0, 0), Size = UDim2.new(1, -45, 1, 0),
                    BackgroundTransparency = 1,
                    Text = plr.DisplayName .. " (@" .. plr.Name .. ")",
                    TextColor3 = Color3.new(1, 1, 1), TextSize = 12, Font = Enum.Font.GothamMedium,
                    TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 22,
                }, pBtn)

                pBtn.MouseButton1Click:Connect(function()
                    playClickSound()
                    selectTarget(plr)
                end)
            end
        end
        if count > 0 then
            targetList.Visible = true
            tween(targetList, 0.2, {Size = UDim2.new(1, 0, 0, math.min(count * 40 + 12, 160))})
        else
            hideTargetList()
        end
    end

    bind(targetBox.Focused, function() updateTargetList(targetBox.Text) end)
    bind(targetBox:GetPropertyChangedSignal("Text"), function()
        if not suppressBox and targetBox:IsFocused() then updateTargetList(targetBox.Text) end
    end)
    -- Enter'a basınca yazılana uyan ilk oyuncuyu seç; kutu boşsa hedefi temizle
    bind(targetBox.FocusLost, function(enterPressed)
        if not enterPressed then return end
        local txt = targetBox.Text
        if txt == "" then clearTarget() return end
        for _, p in ipairs(Players:GetPlayers()) do
            if nameMatches(p, txt) then selectTarget(p) return end
        end
        notify("ESP Hedefi", "Eşleşen oyuncu bulunamadı.", 2)
    end)

    onlyToggle = createToggle(FeaturesPage, "🎯  Sadece Seçili Oyuncunun ESP'si", false, function(v)
        if v and (not espTarget or not espTarget.Parent) then
            notify("Hedef Yok", "Önce yukarıdan ESP hedefi seçin!", 3)
            espTargetOnly = false
            task.defer(function() if onlyToggle then onlyToggle.Set(false, true) end end)
            return
        end
        espTargetOnly = v
        refreshEsp()
        if v then
            notify("Hedefli ESP", espTarget.DisplayName .. " dışında kimse gösterilmeyecek.", 3)
        else
            notify("Hedefli ESP", "Tüm oyuncular tekrar gösteriliyor.", 2)
        end
    end)
end

-- TROLL
createSection(TrollPage, "HEDEF OYUNCU SEÇİMİ VE ARAMA")

do
local selectedTargetPlayer = nil
-- MM2 sekmesi, buradaki seçili oyuncuyu (seçim yapılmadıysa) kullanabilsin diye köprü
Settings.GetSelectedTarget = function() return selectedTargetPlayer end

local dropdownRow, dropdownSt = baseRow(TrollPage, "Frame", 48)
rowLabel(dropdownRow, "Oyuncu Ara / Seç")

local selectBtn = new("TextBox", {
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -12, 0.5, 0),
    Size = UDim2.new(0, 180, 0, 32),
    BackgroundColor3 = Color3.fromRGB(28, 34, 54),
    Text = "",
    PlaceholderText = "İsim yaz (örn: hasan)",
    PlaceholderColor3 = Color3.fromRGB(120, 134, 170),
    TextColor3 = Color3.fromRGB(220, 230, 245),
    TextSize = 12,
    Font = Enum.Font.GothamBold,
    ClearTextOnFocus = false,
    ZIndex = 4,
}, dropdownRow)
corner(selectBtn, 8)
stroke(selectBtn, 1, Color3.fromRGB(55, 65, 95), 0.3)

local DropdownListFrame = new("ScrollingFrame", {
    LayoutOrder = nextOrder(TrollPage),
    Size = UDim2.new(1, 0, 0, 0),
    BackgroundColor3 = Color3.fromRGB(15, 18, 28),
    BackgroundTransparency = 0.05,
    BorderSizePixel = 0,
    ScrollBarThickness = 3,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    Visible = false,
    ZIndex = 20,
}, TrollPage)
corner(DropdownListFrame, 10)
stroke(DropdownListFrame, 1, Color3.fromRGB(60, 75, 110), 0.2)
new("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4)}, DropdownListFrame)
new("UIPadding", {PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6)}, DropdownListFrame)

-- Listede fareyle üzerine gelinen oyuncunun karakteri sağdaki önizlemede gösterilir;
-- hiçbir oyuncunun üzerinde değilken kendi karakterim görünür.
local hoverToken = 0
local shownPlayer = nil   -- nil = kendi karakterim
local function previewPlayer(plr)
    Settings.PlayerPreview(plr)
end

bind(DropdownListFrame:GetPropertyChangedSignal("Visible"), function()
    if not DropdownListFrame.Visible then previewPlayer(nil) end
end)
bind(TrollPage:GetPropertyChangedSignal("Visible"), function()
    if not TrollPage.Visible then previewPlayer(nil) end
end)

local function updatePlayerDropdown(filterText)
    previewPlayer(nil)
    for _, ch in ipairs(DropdownListFrame:GetChildren()) do
        if ch:IsA("TextButton") then ch:Destroy() end
    end

    local matchCount = 0
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local displayName = string.lower(plr.DisplayName)
            local name = string.lower(plr.Name)
            local filter = string.lower(filterText or "")

            if filter == "" or string.sub(name, 1, #filter) == filter or string.sub(displayName, 1, #filter) == filter or string.find(name, filter, 1, true) then
                matchCount = matchCount + 1
                local pBtn = new("TextButton", {
                    Size = UDim2.new(1, 0, 0, 36),
                    BackgroundColor3 = Color3.fromRGB(22, 27, 42),
                    BackgroundTransparency = 0.2,
                    AutoButtonColor = false,
                    Text = "",
                    ZIndex = 21,
                }, DropdownListFrame)
                corner(pBtn, 8)
                ctaFx(pBtn, {radius = 8, colors = false})

                -- Üzerine gelince: satırı parlat + oyuncunun karakterini sağda göster
                pBtn.MouseEnter:Connect(function()
                    tween(pBtn, 0.12, {BackgroundTransparency = 0})
                    previewPlayer(plr)
                end)
                pBtn.MouseLeave:Connect(function()
                    tween(pBtn, 0.18, {BackgroundTransparency = 0.2})
                    previewPlayer(nil)
                end)

                local avImg = new("ImageLabel", {
                    Position = UDim2.new(0, 4, 0, 2),
                    Size = UDim2.new(0, 32, 0, 32),
                    BackgroundTransparency = 1,
                    ZIndex = 22,
                }, pBtn)
                pill(avImg)

                task.spawn(function()
                    pcall(function()
                        local thumb = Players:GetUserThumbnailAsync(plr.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
                        avImg.Image = thumb
                    end)
                end)

                new("TextLabel", {
                    Position = UDim2.new(0, 42, 0, 0),
                    Size = UDim2.new(1, -45, 1, 0),
                    BackgroundTransparency = 1,
                    Text = plr.DisplayName .. " (@" .. plr.Name .. ")",
                    TextColor3 = Color3.new(1, 1, 1),
                    TextSize = 12,
                    Font = Enum.Font.GothamMedium,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 22,
                }, pBtn)

                pBtn.MouseButton1Click:Connect(function()
                    playClickSound()
                    previewPlayer(nil)
                    selectedTargetPlayer = plr
                    setText(selectBtn, plr.Name)
                    DropdownListFrame.Visible = false
                    DropdownListFrame.Size = UDim2.new(1, 0, 0, 0)
                    notify("Hedef Seçildi", plr.Name .. " hedef olarak belirlendi.", 2)
                end)
            end
        end
    end

    if matchCount > 0 then
        DropdownListFrame.Visible = true
        tween(DropdownListFrame, 0.2, {Size = UDim2.new(1, 0, 0, math.min(matchCount * 40 + 12, 160))})
    else
        DropdownListFrame.Visible = false
        DropdownListFrame.Size = UDim2.new(1, 0, 0, 0)
    end
end

bind(selectBtn.Focused, function()
    updatePlayerDropdown(selectBtn.Text)
end)

bind(selectBtn:GetPropertyChangedSignal("Text"), function()
    if selectBtn:IsFocused() then
        updatePlayerDropdown(selectBtn.Text)
    end
end)

createSection(TrollPage, Settings.MM2FlingPlayer and "AKTİF TROLL ÖZELLİKLERİ (12 ADET)" or "AKTİF TROLL ÖZELLİKLERİ (11 ADET)")

local attachedActive = false
local attachConnection = nil
local attachToggleObj
attachToggleObj = createToggle(TrollPage, "🔗  1. Seçilen Kişiye Yapış", false, function(v)
    attachedActive = v
    if attachedActive then
        if not selectedTargetPlayer or not selectedTargetPlayer.Parent then
            notify("Hata", "Lütfen önce yukarıdan hedef oyuncu seçin!", 3)
            attachedActive = false
            task.defer(function() attachToggleObj.Set(false, true) end)
            return
        end
        notify("Yapışma Aktif", selectedTargetPlayer.Name .. " adlı oyuncuya yapışılıyor!", 3)
        attachConnection = RunService.Heartbeat:Connect(function()
            if not attachedActive then return end
            pcall(function()
                local myChar = LocalPlayer.Character
                local targetChar = selectedTargetPlayer.Character
                if myChar and targetChar then
                    local myHrp = myChar:FindFirstChild("HumanoidRootPart")
                    local targetHrp = targetChar:FindFirstChild("HumanoidRootPart")
                    if myHrp and targetHrp then
                        myHrp.CFrame = targetHrp.CFrame * CFrame.new(0, 0, 0)
                        myHrp.Velocity = Vector3.new(0, 0, 0)
                    end
                end
            end)
        end)
    else
        if attachConnection then attachConnection:Disconnect(); attachConnection = nil end
        notify("Yapışma Kapandı", "Oyuncudan ayrıldınız.", 2)
    end
end)

local stickActive = false
local stickConnection = nil
local stickToggleObj
local function tryNetworkOwner(part)
    -- Çoğu executor/oyunda bu çalışmaz (ağ sahipliği sunucuya aittir),
    -- bazılarında çalışabileceği için zararsızca deneniyor.
    pcall(function() part:SetNetworkOwner(LocalPlayer) end)
end
stickToggleObj = createToggle(TrollPage, "📎  1b. Oyuncuyu Kendine Yapıştır", false, function(v)
    stickActive = v
    if stickActive then
        if not selectedTargetPlayer or not selectedTargetPlayer.Parent then
            notify("Hata", "Lütfen önce yukarıdan hedef oyuncu seçin!", 3)
            stickActive = false
            task.defer(function() stickToggleObj.Set(false, true) end)
            return
        end
        if attachedActive then attachToggleObj.Set(false) end
        notify("Yapıştırma Aktif", selectedTargetPlayer.Name .. " sana yapıştırılıyor!", 3)
        local triedOwner = false
        stickConnection = RunService.Heartbeat:Connect(function()
            if not stickActive then return end
            pcall(function()
                local target = selectedTargetPlayer
                local myChar = LocalPlayer.Character
                local targetChar = target and target.Character
                if myChar and targetChar then
                    local myHrp = myChar:FindFirstChild("HumanoidRootPart")
                    local tHrp = targetChar:FindFirstChild("HumanoidRootPart")
                    if myHrp and tHrp then
                        if not triedOwner then
                            triedOwner = true
                            tryNetworkOwner(tHrp)
                        end
                        local goal = myHrp.CFrame * CFrame.new(0, 0, -3)
                        tHrp.CFrame = goal
                        tHrp.AssemblyLinearVelocity = myHrp.AssemblyLinearVelocity
                        tHrp.AssemblyAngularVelocity = Vector3.zero
                    end
                end
            end)
        end)
    else
        if stickConnection then stickConnection:Disconnect() stickConnection = nil end
        notify("Yapıştırma Kapandı", "Oyuncu serbest bırakıldı.", 2)
    end
end)
bind(Players.PlayerRemoving, function(plr)
    if plr == selectedTargetPlayer and stickActive then stickToggleObj.Set(false, true) end
end)

---------------------------------------------------------
-- TROLL ÇEKİRDEĞİ
-- Not: Başka oyuncunun karakterinde doğrudan yapılan değişiklikler
-- (CFrame, Anchored, Jump, BodyVelocity...) sunucuya yansımaz, sadece
-- senin ekranında görünür. Diğer oyunculara gerçekten etki eden tek
-- yol fizik çarpışmasıdır: kendi karakterini hedefin içine ışınlayıp
-- yüksek hızla çarptırmak. Fling / Sky / Sallantı bu yöntemi kullanır.
---------------------------------------------------------
local Troll = {busy = false, fovBusy = false}

function Troll.parts(plr)
    local char = plr and plr.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    return char, hrp, hum
end

function Troll.require()
    if not selectedTargetPlayer or not selectedTargetPlayer.Parent then
        notify("Hata", "Lütfen önce bir hedef oyuncu seçin!", 3)
        return false
    end
    local _, hrp, hum = Troll.parts(selectedTargetPlayer)
    if not hrp or not hum or hum.Health <= 0 then
        notify("Hata", "Hedefin karakteri şu an yok veya ölü.", 3)
        return false
    end
    return true
end

function Troll.flat(a, b)
    return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

-- mode: "fling" | "sky" | "shake" | "pull"
function Troll.attack(mode)
    if Troll.busy then
        notify("Bekle", "Önceki işlem hâlâ sürüyor.", 2)
        return
    end
    if not Troll.require() then return end

    local target = selectedTargetPlayer
    local myChar, myHrp, myHum = Troll.parts(LocalPlayer)
    if not myHrp or not myHum or myHum.Health <= 0 then
        notify("Hata", "Kendi karakterin hazır değil.", 3)
        return
    end

    if mode == "pull" then
        local _, th = Troll.parts(target)
        if th and (th.Position - myHrp.Position).Magnitude < 8 then
            notify("Zaten Yakın", target.Name .. " zaten yanında.", 2)
            return
        end
    end

    Troll.busy = true
    -- "Yapış" açıksa saldırıyla çakışmasın
    if attachedActive then attachToggleObj.Set(false) end

    task.spawn(function()
        local cam = workspace.CurrentCamera
        local oldCF = myHrp.CFrame
        local oldFallen = workspace.FallenPartsDestroyHeight
        local duration = (mode == "fling") and 3 or ((mode == "sky") and 2.5 or ((mode == "space") and 6 or ((mode == "pull") and 4 or 2)))
        local hit = false
        local home = oldCF.Position
        local startDist = 0
        do
            local _, th0 = Troll.parts(target)
            if th0 then startDist = Troll.flat(th0.Position, home) end
        end

        -- Fırlayınca boşluğa düşüp ölmemek için
        pcall(function() workspace.FallenPartsDestroyHeight = -math.huge end)
        pcall(function()
            myHrp.Anchored = false
            local _, _, tHum0 = Troll.parts(target)
            if cam and tHum0 then cam.CameraSubject = tHum0 end
        end)

        pcall(function()
            local startT = os.clock()
            local angle = 0
            while alive and os.clock() - startT < duration do
                local _, tHrp, tHum = Troll.parts(target)
                if not tHrp or not tHum or tHum.Health <= 0 then break end
                if not myHrp.Parent or myHum.Health <= 0 then break end

                angle = angle + 100
                -- Hedef yürüyorsa gideceği yöne doğru önden git
                local lead = tHum.MoveDirection * math.min(tHrp.AssemblyLinearVelocity.Magnitude, 40) / 1.25

                local offset, lin, rot, spin
                if mode == "fling" then
                    local y = (math.floor(angle / 100) % 2 == 0) and 1.5 or -1.5
                    offset = CFrame.new(0, y, 0) + lead
                    lin = Vector3.new(9e7, 9e8, 9e7)
                    rot = Vector3.new(9e8, 9e8, 9e8)
                    spin = CFrame.Angles(math.rad(angle), 0, 0)
                elseif mode == "sky" then
                    offset = CFrame.new(0, -2, 0) + lead
                    lin = Vector3.new(0, 9e5, 0)
                    rot = Vector3.zero
                    spin = CFrame.new()
                elseif mode == "space" then
                    -- Sürekli artan, çok güçlü dikey itiş: hedefi haritanın çok üstüne,
                    -- adeta uzaya kadar fırlatmayı hedefler.
                    local t = os.clock() - startT
                    offset = CFrame.new(0, -2 - t * 4, 0) + lead
                    lin = Vector3.new(0, 1.2e6 + t * 4e5, 0)
                    rot = Vector3.zero
                    spin = CFrame.new()
                elseif mode == "pull" then
                    -- Hedefin arkasından, benim durduğum yere doğru itelerek çek
                    local toHome = Vector3.new(home.X - tHrp.Position.X, 0, home.Z - tHrp.Position.Z)
                    if toHome.Magnitude < 8 then
                        hit = true
                        break
                    end
                    local dir = toHome.Unit
                    offset = CFrame.new(-dir * 1.2 + Vector3.new(0, 0.2, 0))
                    lin = dir * 150 + Vector3.new(0, 12, 0)
                    rot = Vector3.zero
                    spin = CFrame.new()
                else -- shake
                    local a = math.rad(angle * 4)
                    offset = CFrame.new(math.sin(a) * 0.8, 0, math.cos(a) * 0.8)
                    lin = Vector3.new(math.sin(a) * 60, 0, math.cos(a) * 60)
                    rot = Vector3.new(0, 400, 0)
                    spin = CFrame.new()
                end

                myChar:PivotTo(CFrame.new(tHrp.Position) * offset * spin)
                myHrp.AssemblyLinearVelocity = lin
                myHrp.AssemblyAngularVelocity = rot
                task.wait()

                -- Hedef çok hızlandıysa fırlamış demektir
                if (mode == "fling" or mode == "sky" or mode == "space") and tHrp.AssemblyLinearVelocity.Magnitude > 500 then
                    hit = true
                    break
                end
            end
        end)

        -- Kendi karakterini eski yerine güvenle geri götür
        for _ = 1, 20 do
            if not myHrp.Parent then break end
            pcall(function()
                myChar:PivotTo(oldCF)
                myHrp.AssemblyLinearVelocity = Vector3.zero
                myHrp.AssemblyAngularVelocity = Vector3.zero
            end)
            task.wait()
        end
        pcall(function() workspace.FallenPartsDestroyHeight = oldFallen end)
        pcall(function()
            if cam and myHum.Parent then cam.CameraSubject = myHum end
        end)
        Troll.busy = false

        local name = target.Name
        if mode == "fling" then
            if hit then
                notify("Fling Başarılı", name .. " fırlatıldı!", 3)
            else
                notify("Fling Etkisiz", name .. " fırlamadı; oyun fling'e karşı korumalı olabilir.", 4)
            end
        elseif mode == "sky" then
            if hit then
                notify("Havaya Uçuruldu", name .. " havaya fırlatıldı!", 3)
            else
                notify("Sky Etkisiz", name .. " yükselmedi; oyun çarpışmaya karşı korumalı olabilir.", 4)
            end
        elseif mode == "space" then
            if hit then
                notify("Uzaya Fırlatıldı 🚀", name .. " maksimum güçle fırlatıldı!", 3)
            else
                notify("Etkisiz", name .. " yerinden oynamadı; bu oyun çarpışma fiziğine karşı korumalı (ör. anchored/ragdoll kilidi).", 5)
            end
        elseif mode == "pull" then
            local _, thEnd = Troll.parts(target)
            local endDist = thEnd and Troll.flat(thEnd.Position, home) or startDist
            local moved = math.floor(startDist - endDist + 0.5)
            if endDist < 12 then
                notify("Yanına Çekildi", name .. " yanına çekildi!", 3)
            elseif moved >= 10 then
                notify("Kısmen Çekildi", name .. " " .. tostring(moved) .. " stud yaklaştı.", 3)
            else
                notify("Çekilemedi", name .. " yerinden oynamadı; oyun buna karşı korumalı olabilir.", 4)
            end
        else
            notify("Sallantı Bitti", name .. " sallandı (etki oyuna göre değişir).", 3)
        end
    end)
end

createButton(TrollPage, "💥  3. Oyuncuya Patlama Efekti", function()
    if not Troll.require() then return end
    pcall(function()
        local _, hrp = Troll.parts(selectedTargetPlayer)
        local ex = Instance.new("Explosion")
        ex.Position = hrp.Position
        ex.BlastRadius = 12
        ex.BlastPressure = 0
        ex.DestroyJointRadiusPercent = 0
        ex.ExplosionType = Enum.ExplosionType.NoCraters
        ex.Parent = workspace
    end)
    notify("Patlama", "Efekt yalnızca senin ekranında görünür.", 3)
end)

createButton(TrollPage, "☄️  5. Kafasına Taş/Blok Düşür", function()
    if not Troll.require() then return end
    pcall(function()
        local char, hrp = Troll.parts(selectedTargetPlayer)
        local head = char:FindFirstChild("Head") or hrp
        local part = Instance.new("Part")
        part.Size = Vector3.new(3, 3, 3)
        part.Material = Enum.Material.Slate
        part.BrickColor = BrickColor.new("Dark stone grey")
        part.Anchored = false
        part.CanCollide = true
        part.CFrame = CFrame.new(head.Position + Vector3.new(0, 25, 0))
        part.AssemblyLinearVelocity = Vector3.new(0, -80, 0)
        part.Parent = workspace
        task.delay(5, function() part:Destroy() end)
    end)
    notify("Blok Düştü", "Blok yalnızca senin ekranında görünür.", 3)
end)

createButton(TrollPage, "📌  6. Oyuncuyu Olduğu Yere Sabitle", function()
    if not Troll.require() then return end
    local plr = selectedTargetPlayer
    local _, hrp0 = Troll.parts(plr)
    local frozenCF = hrp0.CFrame
    local startT = os.clock()
    local conn
    conn = RunService.Heartbeat:Connect(function()
        local _, h = Troll.parts(plr)
        if not alive or os.clock() - startT >= 3 or not h then
            conn:Disconnect()
            if h then h.Anchored = false end
            return
        end
        h.CFrame = frozenCF
        h.AssemblyLinearVelocity = Vector3.zero
        h.Anchored = true
    end)
    notify("Sabitlendi", plr.Name .. " 3 sn donduruldu (yalnızca senin ekranında).", 3)
end)

createButton(TrollPage, "💃  7. Oyuncuyu Sars / Sallantı Ver", function()
    Troll.attack("shake")
end)

createButton(TrollPage, "🕶️  8. Hedefin Bilgilerini Al", function()
    if not selectedTargetPlayer or not selectedTargetPlayer.Parent then
        notify("Hata", "Lütfen önce bir hedef oyuncu seçin!", 3)
        return
    end
    local plr = selectedTargetPlayer
    local _, hrp, hum = Troll.parts(plr)

    local line1 = plr.DisplayName .. " (@" .. plr.Name .. ")  •  ID: " .. tostring(plr.UserId)
    local line2 = "Hesap yaşı: " .. tostring(plr.AccountAge) .. " gün  •  Takım: " .. (plr.Team and plr.Team.Name or "Yok")
    local line3 = "Karakter şu an yüklü değil."
    if hum and hrp then
        local myHrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        local dist = myHrp and tostring(math.floor((myHrp.Position - hrp.Position).Magnitude + 0.5)) or "?"
        line3 = "Can: " .. tostring(math.floor(hum.Health)) .. "/" .. tostring(math.floor(hum.MaxHealth))
            .. "  •  Hız: " .. tostring(math.floor(hum.WalkSpeed))
            .. "  •  Mesafe: " .. dist .. " m"
    end

    notify("Hedef Bilgisi", line1, 5)
    task.delay(0.15, function() notify("Hesap", line2, 5) end)
    task.delay(0.3, function() notify("Durum", line3, 5) end)
end)

createButton(TrollPage, "🔄  9. Kamera Efekti (FOV Trolling)", function()
    if Troll.fovBusy then return end
    local cam = workspace.CurrentCamera
    if not cam then return end
    Troll.fovBusy = true
    local origFov = cam.FieldOfView
    local startT = os.clock()
    RunService:BindToRenderStep("EZRAGOX_FOV", Enum.RenderPriority.Camera.Value + 1, function()
        local t = os.clock() - startT
        if t >= 2 or not alive then
            RunService:UnbindFromRenderStep("EZRAGOX_FOV")
            cam.FieldOfView = origFov
            Troll.fovBusy = false
            return
        end
        cam.FieldOfView = math.clamp(75 + math.sin(t * 31) * 40, 20, 120)
    end)
    notify("Kamera Troll", "Kamera efektleri uygulandı!", 2)
end)

createButton(TrollPage, "💨  10. Sunucudaki Herkesi Zıplat", function()
    for _, p in ipairs(Players:GetPlayers()) do
        pcall(function()
            local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
            if hum then
                hum.Jump = true
            end
        end)
    end
    notify("Toplu Zıplama", "Sunucudaki herkes zıplatıldı!", 2)
end)

-- 11. SEÇİLEN OYUNCUYU İZLE (Spectate)
local Spectate = {on = false, conn = nil}
local spectateToggleObj

local function restoreOwnCamera()
    pcall(function()
        local cam = workspace.CurrentCamera
        local myChar = LocalPlayer.Character
        local myHum = myChar and myChar:FindFirstChildOfClass("Humanoid")
        if cam and myHum then
            cam.CameraSubject = myHum
        end
    end)
end

local function stopSpectate()
    Spectate.on = false
    if Spectate.conn then
        Spectate.conn:Disconnect()
        Spectate.conn = nil
    end
    restoreOwnCamera()
end

spectateToggleObj = createToggle(TrollPage, "👁️  11. Seçilen Oyuncuyu İzle", false, function(v)
    if v then
        if not selectedTargetPlayer or not selectedTargetPlayer.Parent then
            notify("Hata", "Lütfen önce yukarıdan hedef oyuncu seçin!", 3)
            task.defer(function() spectateToggleObj.Set(false, true) end)
            return
        end
        Spectate.on = true
        notify("İzleme Aktif", selectedTargetPlayer.Name .. " adlı oyuncu izleniyor!", 3)
        if Spectate.conn then Spectate.conn:Disconnect() end
        Spectate.conn = bind(RunService.RenderStepped, function()
            if not Spectate.on then return end

            -- Hedef oyundan çıktıysa izlemeyi otomatik kapat
            local target = selectedTargetPlayer
            if not target or not target.Parent then
                stopSpectate()
                notify("İzleme Kapandı", "Hedef oyuncu oyundan ayrıldı.", 3)
                task.defer(function() spectateToggleObj.Set(false, true) end)
                return
            end

            -- Hedef ölüp yeniden doğunca (veya hedef değiştirilince) kamerayı yeni Humanoid'e bağla
            pcall(function()
                local cam = workspace.CurrentCamera
                local hum = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
                if cam and hum and cam.CameraSubject ~= hum then
                    cam.CameraSubject = hum
                end
            end)
        end)
    else
        stopSpectate()
        notify("İzleme Kapandı", "Kamera kendi karakterine döndü.", 2)
    end
end)

-- 12. SEÇİLEN OYUNCUNUN YANINA IŞINLAN
createButton(TrollPage, "🚀  12. Seçilen Oyuncunun Yanına Işınlan", function()
    if Troll.busy then
        notify("Bekle", "Önceki işlem hâlâ sürüyor.", 2)
        return
    end
    if not Troll.require() then return end
    local myChar, myHrp = Troll.parts(LocalPlayer)
    local _, tHrp = Troll.parts(selectedTargetPlayer)
    if not myChar or not myHrp then
        notify("Hata", "Kendi karakterin hazır değil.", 3)
        return
    end
    -- Hedefin hemen arkasına, aynı yöne bakarak
    myChar:PivotTo(tHrp.CFrame * CFrame.new(0, 0, 4))
    myHrp.AssemblyLinearVelocity = Vector3.zero
    notify("Işınlandın", selectedTargetPlayer.Name .. " adlı oyuncunun yanındasın!", 2)
end)

-- 13. SEÇİLEN OYUNCUYU YANIMA ÇEK (fizik ile iterek)
createButton(TrollPage, "🎣  13. Seçilen Oyuncuyu Yanıma Çek", function()
    Troll.attack("pull")
end)

-- 14. SEÇİLİ OYUNCUYU FIRLAT (1000x) — MM2 sekmesindeki ile aynı özellik (yalnızca MM2'de eklenir)
if Settings.MM2FlingPlayer then
    createButton(TrollPage, "💥  14. Seçili Oyuncuyu Fırlat (1000x)", function()
        Settings.MM2FlingPlayer(selectedTargetPlayer)
    end)
end

end

---------------------------------------------------------
-- PREMİUM (ANAHTAR SİSTEMİ) + YÖNETİM (SADECE SAHİBİ İÇİN)
---------------------------------------------------------
do
local PX = {
    unlocked = false,   -- premium açık mı
    admin = false,      -- yönetim girişi yapıldı mı
    lockRows = {},      -- kilitliyken görünen satırlar
    premiumRows = {},   -- açılınca görünen satırlar
    toggles = {},       -- premium anahtarları (kilitlenince kapatılır)
    onLock = {},        -- kilitlenince çalışacak temizlik fonksiyonları
    wrong = 0,
    cooldownUntil = 0,
    adminWrong = 0,
    adminCooldownUntil = 0,
    real = "",
    rows = {},
    adminTab = AdminTab,
    secHolders = {},    -- bölüm başlıkları (sıralama için)
    collapsibles = {},  -- açılır menü gövdeleri (premium kilidi bunları açmaz)
}

local ADMIN_HASH = 945129088          -- yönetim şifresinin özeti (düz şifre kodda yazmaz)
local ADMIN_HOTKEY = Enum.KeyCode.Y         -- Ctrl + Shift + Y  => yönetim girişi

-- PREMİUM HESAPLAR (Roblox kullanıcı adı). Veritabanı kullanmıyorsan premium vereceklerini buraya yaz.
local PREMIUM_NAMES = { }

-- Premium hesapları herkesin cihazında görmek için ortak veritabanı (Firebase Realtime Database - ücretsiz).
-- Örnek: "https://proje-adin-default-rtdb.firebaseio.com"   (boş bırakırsan sadece PREMIUM_NAMES listesi kullanılır)
local KEY_DB_URL = "https://veri-aa690-default-rtdb.europe-west1.firebasedatabase.app"
local SECRET_FILE = "ezragox_admin_secret.txt"   -- veritabanı gizli anahtarı SADECE senin cihazında bu dosyada durur

---------------------------------------------------------
-- YARDIMCI FONKSİYONLAR
---------------------------------------------------------
function PX.hash32(str, seed)
    local h = seed or 5381
    for i = 1, #str do
        h = (h * 33 + string.byte(str, i) * ((i % 7) + 1) + 17) % 4294967296
    end
    return h
end

function PX.checkAdmin(pw)
    local s = tostring(pw or "")
    s = s:gsub("%s", "")
    return PX.hash32("EZRX_ADMIN|" .. s, 9871) == ADMIN_HASH
end

function PX.copy(text)
    local ok = false
    pcall(function()
        if setclipboard then
            setclipboard(text)
            ok = true
        end
    end)
    return ok
end

function PX.openDiscord()
    task.spawn(function()
        -- 1) Tarayıcıda (Chrome vb.) aç
        pcall(function() GuiService:OpenBrowserWindow(DISCORD_URL) end)
        pcall(function() if openurl then openurl(DISCORD_URL) end end)
        -- 2) Bağlantıyı panoya kopyala (açılmazsa yapıştırıp girebilsin)
        pcall(function() if setclipboard then setclipboard(DISCORD_URL) end end)
        -- 3) Discord uygulaması açıksa davet penceresini doğrudan uygulamada aç
        pcall(function()
            local req = request or http_request or (syn and syn.request)
            local code = string.match(DISCORD_URL, "discord%.gg/(%w+)")
            if req and code then
                req({
                    Url = "http://127.0.0.1:6463/rpc?v=1",
                    Method = "POST",
                    Headers = {["Content-Type"] = "application/json", ["Origin"] = "https://discord.com"},
                    Body = HttpService:JSONEncode({
                        cmd = "INVITE_BROWSER",
                        args = {code = code},
                        nonce = HttpService:GenerateGUID(false),
                    }),
                })
            end
        end)
    end)
    notify("Discord Sunucusu", "Açılıyor... Açılmazsa bağlantı panoya kopyalandı.", 4)
end

---------------------------------------------------------
-- ORTAK ARAYÜZ PARÇALARI
---------------------------------------------------------
function PX.infoCard(page, title, body, height)
    local row = baseRow(page, "Frame", height)
    local t = new("TextLabel", {
        Position = UDim2.new(0, 14, 0, 10), Size = UDim2.new(1, -28, 0, 18), BackgroundTransparency = 1,
        Text = title, Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = Color3.new(1, 1, 1),
        TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4,
    }, row)
    local b = new("TextLabel", {
        Position = UDim2.new(0, 14, 0, 32), Size = UDim2.new(1, -28, 1, -40), BackgroundTransparency = 1,
        Text = body, Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = Color3.fromRGB(150, 163, 195),
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
        TextWrapped = true, ZIndex = 4,
    }, row)
    return row, t, b
end

function PX.inputRow(page, label, placeholder)
    local row = baseRow(page, "Frame", 48)
    local lbl = rowLabel(row, label)
    lbl.Size = UDim2.new(0, 80, 0, 20)
    lbl.Position = UDim2.new(0, 14, 0.5, -10)
    local box = new("TextBox", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.new(1, -108, 0, 32),
        BackgroundColor3 = Color3.fromRGB(28, 14, 20), Text = "", PlaceholderText = placeholder,
        PlaceholderColor3 = Color3.fromRGB(130, 100, 108), TextColor3 = Color3.fromRGB(255, 214, 102),
        TextSize = 13, Font = Enum.Font.Code, ClearTextOnFocus = false, ZIndex = 4,
    }, row)
    corner(box, 8)
    stroke(box, 1, Color3.fromRGB(135, 40, 55), 0.3)
    return row, box, lbl
end

local function snapshot(page)
    local s = {}
    for _, c in ipairs(page:GetChildren()) do s[c] = true end
    return s
end
local function collectNew(page, before, list)
    for _, c in ipairs(page:GetChildren()) do
        if not before[c] and c:IsA("GuiObject") then list[#list + 1] = c end
    end
end

-- Premium bileşenleri: kilitliyken çalışmaz
function PX.toggle(text, cb)
    local obj
    obj = createToggle(PremiumPage, text, false, function(v)
        if v and not PX.unlocked then
            obj.Set(false, true)
            notify("Premium Gerekli", "Önce geçerli bir anahtar gir.", 3)
            return
        end
        cb(v)
    end, false)
    PX.toggles[#PX.toggles + 1] = obj
    return obj
end
function PX.button(text, cb)
    return createButton(PremiumPage, text, function()
        if not PX.unlocked then return end
        cb()
    end)
end
function PX.slider(text, min, max, default, cb, suffix)
    return createSlider(PremiumPage, text, min, max, default, function(v)
        if PX.unlocked then cb(v) end
    end, suffix)
end

---------------------------------------------------------
-- PREMİUM SEKMESİ
---------------------------------------------------------
do
    local badge = new("TextLabel", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), Size = UDim2.new(0, 26, 0, 15),
        BackgroundColor3 = Color3.fromRGB(255, 190, 60), Text = "PRO", Font = Enum.Font.GothamBlack,
        TextSize = 9, TextColor3 = Color3.fromRGB(45, 22, 0), ZIndex = 6,
    }, PremiumTab.btn)
    corner(badge, 6)
end

-- 1) Kilitli ekran
do
    local before = snapshot(PremiumPage)
    PX.secHolders.lock = createSection(PremiumPage, "PREMİUM KİLİDİ")
    PX.infoCard(PremiumPage, trText("👑  EZRAGOX PREMİUM"), "Noclip • Tıkla-Işınlan • Fullbright • Gökkuşağı Aura • Dönen Karakter • Yerçekimi • FOV • Zoom Kilidi • Gün Saati • Anti-AFK • Rejoin ve daha fazlası. Premium, Roblox hesabına özel tanımlanır.", 92)
    PX.infoCard(PremiumPage, trText("👤  Hesabın: ") .. LocalPlayer.Name, trText("Bu hesapta premium tanımlı değil. Premium istemek için Discord sunucusuna gel."), 62)
    createButton(PremiumPage, "🔄  Premium Durumunu Yenile", function()
        PX.checkPremium(false)
    end)
    createButton(PremiumPage, "🔑  Premium İste  (Discord Sunucusu)", function()
        PX.openDiscord()
    end)
    collectNew(PremiumPage, before, PX.lockRows)
end

-- 2) Açık ekran (özellikler)
do
    local before = snapshot(PremiumPage)

    PX.secHolders.status = createSection(PremiumPage, "PREMİUM DURUMU")
    local _, _, statusBody = PX.infoCard(PremiumPage, trText("✅  PREMİUM AKTİF"), "", 58)
    PX.statusBody = statusBody

    createSection(PremiumPage, "👑  PREMİUM HAREKET")

    -- Noclip
    do
        local noclipOn, touched = false, {}
        bind(RunService.Stepped, function()
            if not noclipOn then return end
            local char = LocalPlayer.Character
            if not char then return end
            for _, p in ipairs(Settings.CharParts(char)) do
                if p.CanCollide then
                    touched[p] = true
                    p.CanCollide = false
                end
            end
        end)
        PX.toggle("👻  Noclip (Duvarlardan Geç)", function(v)
            noclipOn = v
            if v then
                notify("Noclip", "Aktif! Duvarların içinden geçebilirsin.", 2)
            else
                for p in pairs(touched) do
                    if p and p.Parent then p.CanCollide = true end
                end
                touched = {}
            end
        end)
    end

    -- Tıkla-Işınlan
    do
        local clickTp = false
        local mouse = LocalPlayer:GetMouse()
        bind(UserInputService.InputBegan, function(input, gpe)
            if gpe or not clickTp or not PX.unlocked then return end
            if input.UserInputType == Enum.UserInputType.MouseButton1
                and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
                local char = LocalPlayer.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if hrp and mouse.Hit then
                    hrp.CFrame = CFrame.new(mouse.Hit.Position + Vector3.new(0, 3, 0))
                end
            end
        end)
        PX.toggle("🖱️  Tıkla-Işınlan  (Ctrl + Sol Tık)", function(v)
            clickTp = v
            if v then notify("Tıkla-Işınlan", "Ctrl basılıyken bir yere sol tıkla.", 3) end
        end)
    end

    -- Dönen karakter
    do
        local spinOn, spinSpeed = false, 10
        bind(RunService.RenderStepped, function(dt)
            if not spinOn then return end
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                hrp.CFrame = hrp.CFrame * CFrame.Angles(0, math.rad(spinSpeed * 36 * dt), 0)
            end
        end)
        PX.toggle("🌀  Dönen Karakter (Spin)", function(v)
            spinOn = v
            if v then notify("Spin", "Karakterin dönmeye başladı!", 2) end
        end)
        PX.slider("🌪️  Dönme Hızı", 1, 20, 10, function(v) spinSpeed = v end)
    end

    -- Yerçekimi
    do
        local origGravity = workspace.Gravity
        PX.slider("🪐  Yerçekimi", 10, 400, math.clamp(math.floor(origGravity + 0.5), 10, 400), function(v)
            workspace.Gravity = v
        end)
        PX.onLock[#PX.onLock + 1] = function() workspace.Gravity = origGravity end
        PX.button("♻️  Yerçekimini Normale Döndür", function()
            workspace.Gravity = origGravity
            notify("Yerçekimi", "Normal değere döndü.", 2)
        end)
    end

    -- God Mode (ölümsüzlük; sadece reset atınca ölürsün)
    do
        local StarterGui = game:GetService("StarterGui")
        local godOn, bypass, hum = false, false, nil
        local godConns = {}
        local resetEvent = Instance.new("BindableEvent")

        local function dropConns()
            for _, c in ipairs(godConns) do pcall(function() c:Disconnect() end) end
            godConns = {}
        end
        local function heal()
            if godOn and not bypass and hum and hum.Parent and hum.Health < hum.MaxHealth then
                pcall(function() hum.Health = hum.MaxHealth end)
            end
        end
        local function attach(char)
            dropConns()
            local h = char and char:FindFirstChildOfClass("Humanoid")
            if not h then return end
            hum = h
            pcall(function() h:SetStateEnabled(Enum.HumanoidStateType.Dead, false) end)
            godConns[#godConns + 1] = h.HealthChanged:Connect(heal)
            godConns[#godConns + 1] = h.StateChanged:Connect(function(_, new)
                if godOn and not bypass and new == Enum.HumanoidStateType.Dead then
                    pcall(function() h:ChangeState(Enum.HumanoidStateType.GettingUp) end)
                end
            end)
            heal()
        end
        local function disable()
            godOn = false
            dropConns()
            if hum and hum.Parent then
                pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Dead, true) end)
            end
            pcall(function() StarterGui:SetCore("ResetButtonCallback", true) end)
        end

        -- Reset tuşu: God Mode'u atlayıp karakteri gerçekten öldürür
        bind(resetEvent.Event, function()
            bypass = true
            local char = LocalPlayer.Character
            if hum and hum.Parent then
                pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Dead, true) end)
                pcall(function() hum.Health = 0 end)
            end
            if char then pcall(function() char:BreakJoints() end) end
        end)

        bind(RunService.Heartbeat, heal)
        bind(LocalPlayer.CharacterAdded, function(char)
            bypass = false
            if godOn then
                task.wait(0.15)
                attach(char)
            end
        end)

        PX.toggle("🛡️  God Mode  (Ölümsüzlük — Sadece Reset ile Ölürsün)", function(v)
            if v then
                godOn, bypass = true, false
                attach(LocalPlayer.Character)
                pcall(function() StarterGui:SetCore("ResetButtonCallback", resetEvent) end)
                notify("God Mode", "Aktif! Ölmezsin; ölmek için Reset at.", 3)
            else
                disable()
                notify("God Mode", "Kapatıldı.", 2)
            end
        end)
        PX.onLock[#PX.onLock + 1] = disable
    end

    createSection(PremiumPage, "🌅  PREMİUM EKRAN & IŞIK")

    -- Fullbright
    do
        local saved = nil
        PX.toggle("💡  Fullbright (Her Yer Aydınlık)", function(v)
            pcall(function()
                if v then
                    saved = {
                        Brightness = Lighting.Brightness, ClockTime = Lighting.ClockTime,
                        FogEnd = Lighting.FogEnd, GlobalShadows = Lighting.GlobalShadows,
                        Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient,
                    }
                    Lighting.Brightness = 2
                    Lighting.ClockTime = 14
                    Lighting.FogEnd = 100000
                    Lighting.GlobalShadows = false
                    Lighting.Ambient = Color3.fromRGB(178, 178, 178)
                    Lighting.OutdoorAmbient = Color3.fromRGB(178, 178, 178)
                    notify("Fullbright", "Her yer aydınlandı!", 2)
                elseif saved then
                    for k, val in pairs(saved) do Lighting[k] = val end
                    saved = nil
                end
            end)
        end)
    end

    -- FOV
    do
        local cam0 = workspace.CurrentCamera
        local fov0 = cam0 and cam0.FieldOfView or 70
        PX.slider("🔭  Görüş Açısı (FOV)", 40, 120, math.clamp(math.floor(fov0 + 0.5), 40, 120), function(v)
            local cam = workspace.CurrentCamera
            if cam then cam.FieldOfView = v end
        end, "°")
    end

    -- Zoom kilidi
    do
        local origMax, origMin = LocalPlayer.CameraMaxZoomDistance, LocalPlayer.CameraMinZoomDistance
        PX.toggle("🔍  Kamera Zoom Sınırını Kaldır", function(v)
            pcall(function()
                if v then
                    LocalPlayer.CameraMaxZoomDistance = 1000
                    LocalPlayer.CameraMinZoomDistance = 0.5
                    notify("Zoom", "Uzaklaşma sınırı kaldırıldı.", 2)
                else
                    LocalPlayer.CameraMaxZoomDistance = origMax
                    LocalPlayer.CameraMinZoomDistance = origMin
                end
            end)
        end)
    end

    -- Gün saati
    PX.slider("🌙  Gün Saati", 0, 24, math.clamp(math.floor(Lighting.ClockTime), 0, 24), function(v)
        pcall(function() Lighting.ClockTime = v end)
    end, " sa")

    createSection(PremiumPage, "🚀  PREMİUM FPS ARTIRICI")

    -- Tek anahtar: düşük grafik, plastik materyal, gölge/ışık/post efekt/partikül/doku temizliği,
    -- diğer oyuncu animasyonlarını durdurma, aksesuarları gizleme, ceset temizliği ve hafif karartma.
    PX.toggle("🚀  FPS Artırıcı PRO  (Maksimum Akıcılık)", function(v)
        Settings.FPSX.flags.pro = v
        Settings.FPSX.refresh()
        if v then
            notify("FPS Artırıcı PRO", "Aktif! Işıklar, efektler, dokular ve aksesuarlar kapatıldı; ölen oyuncuların cesetleri artık ekranında görünmez.", 3)
        else
            notify("FPS Artırıcı PRO", "Kapatıldı. Grafikler eski haline döndü.", 3)
        end
    end)

    -- Kayıtlı "açık" durumu: premium doğrulanır doğrulanmaz PRO modunu gerçekten başlat (script her açılışta)
    PX.onLock[#PX.onLock + 1] = function()
        Settings.FPSX.flags.pro = false
        Settings.FPSX.refresh()
    end
    task.spawn(function()
        local key = "🚀  FPS Artırıcı PRO  (Maksimum Akıcılık)"
        while alive do
            if PX.unlocked and Settings.ToggleStates[key] == true and not Settings.FPSX.flags.pro then
                suppressNotify = true
                Settings.FPSX.flags.pro = true
                Settings.FPSX.refresh()
                suppressNotify = false
            elseif not PX.unlocked and Settings.FPSX.flags.pro then
                Settings.FPSX.flags.pro = false
                Settings.FPSX.refresh()
            end
            task.wait(1.5)
        end
    end)

    -- Executor destekliyorsa FPS sınırını yükseltir (setfpscap)
    do
        local sv = Settings.SliderValues["🎯  FPS Sınırı  (executor destekliyorsa)"]
        if type(sv) == "number" then Settings.FPSX.cap = 360 end -- Eski kayıtlı 60/144 değeri otomatik olarak maksimuma çekilir.
    end
    PX.slider("🎯  FPS Sınırı  (executor destekliyorsa)", 60, 360, 360, function(v)
        Settings.FPSX.setCap(v)
    end, " fps")

    createSection(PremiumPage, "🌌  GÖKYÜZÜ SEÇİMİ")

    -- Gökyüzü değiştir (tıklayınca aşağı doğru açılan panel)
    do
        local SKY_PRESETS = {
            {name = "Gökyüzü 1", id = 8202961731},
            {name = "Gökyüzü 2", id = 82796424171704},
            {name = "Gökyüzü 3", id = 11675661848},
            {name = "Gökyüzü 4", id = 8202961731},
            {name = "Gökyüzü 5", id = 136055162054954},
        }
        -- Oyunun kendi Sky nesneleri burada saklanır (sıfırlayınca geri konur).
        -- Not: Lighting'de birden fazla Sky varsa oyun eskisini kullanır; bu yüzden
        -- hepsi kaldırılır ve oyun yenisini eklerse de anında kaldırılır.
        local skyState = nil
        if getgenv then
            local ok, shared = pcall(function() return getgenv().EZRAGOX_SKY_STATE end)
            if ok and type(shared) == "table" then skyState = shared end
        end
        skyState = skyState or {stashed = {}, customSky = nil, selectedId = Settings.SelectedSkyId}
        local stashed = skyState.stashed or {}
        local customSky, skyToken, skyGuardOn = skyState.customSky, 0, false
        local FACES = {"SkyboxBk", "SkyboxDn", "SkyboxFt", "SkyboxLf", "SkyboxRt", "SkyboxUp"}
        local function syncSkyState()
            skyState.stashed = stashed
            skyState.customSky = customSky
            skyState.selectedId = Settings.SelectedSkyId
            if getgenv then pcall(function() getgenv().EZRAGOX_SKY_STATE = skyState end) end
        end
        syncSkyState()

        local function stashOthers()
            for _, ch in ipairs(Lighting:GetChildren()) do
                if ch:IsA("Sky") and ch ~= customSky then
                    if ch.Name == "EZRAGOX_Sky" then
                        pcall(function() ch:Destroy() end)
                    else
                        stashed[#stashed + 1] = ch
                        ch.Parent = nil
                    end
                end
            end
        end

        bind(Lighting.ChildAdded, function(ch)
            if skyGuardOn and ch:IsA("Sky") and ch ~= customSky then
                task.defer(function()
                    if skyGuardOn and ch.Parent == Lighting and ch ~= customSky then
                        pcall(function()
                            stashed[#stashed + 1] = ch
                            ch.Parent = nil
                        end)
                    end
                end)
            end
        end)
        task.spawn(function()
            while alive do
                if skyGuardOn and customSky and customSky.Parent ~= Lighting then
                    pcall(function() customSky.Parent = Lighting end)
                end
                task.wait(1)
            end
        end)

        -- ID'yi çöz: Toolbox "Skybox" varlığı (içinde Sky olan model), Decal veya düz resim olabilir.
        -- Eskiden ID doğrudan resim sanılıyordu; Sky/Decal ID'leri bu yüzden görünmüyordu.
        local function resolveSky(id)
            local sid = "rbxassetid://" .. tostring(id)
            local okG, objs = pcall(function() return game:GetObjects(sid) end)
            if okG and type(objs) == "table" then
                for _, o in ipairs(objs) do
                    if o:IsA("Sky") then return {sky = o, kind = "Sky"} end
                    local inner = o:FindFirstChildWhichIsA("Sky", true)
                    if inner then return {sky = inner, kind = "Sky"} end
                    if (o:IsA("Decal") or o:IsA("Texture")) and o.Texture ~= "" then
                        return {img = o.Texture, kind = "Decal"}
                    end
                    if (o:IsA("ImageLabel") or o:IsA("ImageButton")) and o.Image ~= "" then
                        return {img = o.Image, kind = "Decal"}
                    end
                    local dec = o:FindFirstChildWhichIsA("Decal", true)
                    if dec and dec.Texture ~= "" then return {img = dec.Texture, kind = "Decal"} end
                end
            end
            return {img = sid, kind = "Resim"}
        end

        local function applySky(id)
            skyToken = skyToken + 1
            local myToken = skyToken
            pcall(notifyTop, "🌌 Gökyüzü yükleniyor...", 2)
            task.spawn(function()
                local res = resolveSky(id)
                if myToken ~= skyToken or not alive then return end
                local ok = pcall(function()
                    local newSky
                    if res.sky then
                        newSky = res.sky:Clone()
                    else
                        newSky = Instance.new("Sky")
                        for _, f in ipairs(FACES) do newSky[f] = res.img end
                    end
                    newSky.Name = "EZRAGOX_Sky"
                    if customSky then pcall(function() customSky:Destroy() end) customSky = nil end
                    skyGuardOn = true
                    stashOthers()
                    customSky = newSky
                    newSky.Parent = Lighting
                    Settings.SelectedSkyId = tonumber(id)
                    saveConfig()
                    syncSkyState()
                end)
                if ok then
                    pcall(notifyTop, "🌌 Gökyüzü uygulandı! (" .. res.kind .. ")", 3)
                else
                    pcall(notifyTop, "🌌 Gökyüzü uygulanamadı (kod hatası).", 3.5)
                end
            end)
        end

        local function resetSky(silent)
            skyToken = skyToken + 1
            skyGuardOn = false
            pcall(function()
                if customSky then customSky:Destroy() customSky = nil end
                -- En yeni geçerli oyun gökyüzünü geri koy
                for i = #stashed, 1, -1 do
                    local ch = stashed[i]
                    local okP = pcall(function()
                        if ch.Parent == nil then ch.Parent = Lighting end
                    end)
                    if okP and ch.Parent == Lighting then break end
                end
                stashed = {}
                Settings.SelectedSkyId = nil
                saveConfig()
                syncSkyState()
            end)
            if silent ~= true then
                pcall(notifyTop, "🌌 Gökyüzü varsayılana döndürüldü.", 2.5)
            end
        end

        skyCleanup = function() resetSky(true) end

        -- Son seçilen gökyüzünü script yeniden çalıştırıldığında otomatik uygula.
        local rememberedSky = tonumber(Settings.SelectedSkyId) or tonumber(skyState.selectedId)
        if rememberedSky then
            Settings.SelectedSkyId = rememberedSky
            task.defer(function()
                if alive then applySky(rememberedSky) end
            end)
        elseif customSky and customSky.Parent ~= Lighting then
            pcall(function() customSky.Parent = Lighting end)
        end

        -- Başlık satırı: tıklayınca altındaki panel açılır/kapanır
        local header, headerSt = baseRow(PremiumPage, "TextButton", 42)
        local hLbl = rowLabel(header, "🌌  Gökyüzü Değiştir")
        local arrow = new("TextLabel", {
            Size = UDim2.new(0, 30, 1, 0), Position = UDim2.new(1, -36, 0, 0), BackgroundTransparency = 1,
            Text = "▾", Font = Enum.Font.GothamBold, TextSize = 18, TextColor3 = Color3.fromRGB(120, 134, 170), ZIndex = 4,
        }, header)
        hoverFx(header, headerSt)

        local PANEL_H = 300
        local content = new("Frame", {
            LayoutOrder = nextOrder(PremiumPage),
            Size = UDim2.new(1, 0, 0, 0),
            BackgroundTransparency = 1,
            ClipsDescendants = true,
            ZIndex = 3,
        }, PremiumPage)
        new("UIPadding", {PaddingTop = UDim.new(0, 8)}, content)
        new("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6)}, content)

        local function premGuard(cb)
            return function()
                if not PX.unlocked then
                    notify("Premium Gerekli", "Önce geçerli bir anahtar gir.", 3)
                    pcall(notifyTop, "🔒 Premium gerekli.", 2.5)
                    return
                end
                cb()
            end
        end

        for _, preset in ipairs(SKY_PRESETS) do
            createButton(content, "🌠  " .. preset.name, premGuard(function() applySky(preset.id) end))
        end
        createButton(content, "♻️  Gökyüzünü Sıfırla (Varsayılan)", premGuard(resetSky))

        local panelOpen = false
        bind(header.MouseButton1Click, function()
            if not PX.unlocked then
                notify("Premium Gerekli", "Önce geçerli bir anahtar gir.", 3)
                pcall(notifyTop, "🔒 Premium gerekli.", 2.5)
                return
            end
            playClickSound()
            panelOpen = not panelOpen
            setText(arrow, panelOpen and "▴" or "▾")
            tween(content, 0.22, {Size = UDim2.new(1, 0, 0, panelOpen and PANEL_H or 0)})
        end)
    end

-- 🎭 PREMİUM ANİMASYON PAKETLERİ: duruş + yürüme + koşma + zıplama + düşme + tırmanma + yüzme hepsi bir arada
PX.secHolders.anim = createSection(PremiumPage, "🎭  PREMİUM ANİMASYON PAKETLERİ")
;(function()
    local ContentProvider = game:GetService("ContentProvider")

    -- Roblox'un resmi R15 animasyon paketleri. Her pakette tüm hareketler birlikte değişir.
    local PACKS = {
        {name = "Vampir",     idle1 = 1083445855, idle2 = 1083450166, walk = 1083473930, run = 1083462077, jump = 1083455352, fall = 1083443587, climb = 1083439238, swim = 1083464683, swimidle = 1083467779},
        {name = "Kahraman",   idle1 = 616111295,  idle2 = 616113536,  walk = 616122287,  run = 616117076,  jump = 616115533,  fall = 616108001,  climb = 616104706,  swim = 616119360,  swimidle = 616120861},
        {name = "Zombi",      idle1 = 616158929,  idle2 = 616160636,  walk = 616168032,  run = 616163682,  jump = 616161997,  fall = 616157476,  climb = 616156119,  swim = 616165109,  swimidle = 616166655},
        {name = "Ninja",      idle1 = 656117400,  idle2 = 656118341,  walk = 656121766,  run = 656118852,  jump = 656117878,  fall = 656115606,  climb = 656114359,  swim = 656119721,  swimidle = 656121397},
        {name = "Astronot",   idle1 = 891621366,  idle2 = 891633237,  walk = 891667138,  run = 891636393,  jump = 891627522,  fall = 891617961,  climb = 891609353,  swim = 891639666,  swimidle = 891663592},
        {name = "Levitasyon", idle1 = 616006778,  idle2 = 616008087,  walk = 616013216,  run = 616010382,  jump = 616008936,  fall = 616005863,  climb = 616003713,  swim = 616011509,  swimidle = 616012453},
        {name = "Büyücü",     idle1 = 707742142,  idle2 = 707855907,  walk = 707897309,  run = 707861613,  jump = 707853694,  fall = 707829716,  climb = 707826056,  swim = 707876443,  swimidle = 707894699},
        {name = "Şövalye",    idle1 = 657595757,  idle2 = 657568135,  walk = 657552124,  run = 657564596,  jump = 658409194,  fall = 657600338,  climb = 658360781,  swim = 657560551,  swimidle = 657557095},
        {name = "Korsan",     idle1 = 750781874,  idle2 = 750782770,  walk = 750785693,  run = 750783738,  jump = 750782230,  fall = 750780242,  climb = 750779899,  swim = 750784579,  swimidle = 750785176},
        {name = "Robot",      idle1 = 616088211,  idle2 = 616089559,  walk = 616095330,  run = 616091570,  jump = 616090535,  fall = 616087089,  climb = 616086039,  swim = 616092998,  swimidle = 616094091},
        {name = "Oyuncak",    idle1 = 782841498,  idle2 = 782845736,  walk = 782843345,  run = 782842708,  jump = 782847020,  fall = 782846423,  climb = 782843869,  swim = 782844582,  swimidle = 782845186},
        {name = "Kurt Adam",  idle1 = 1083195517, idle2 = 1083214717, walk = 1083178339, run = 1083216690, jump = 1083218792, fall = 1083189019, climb = 1083182000, swim = 1083222527, swimidle = 1083225406},
        {name = "Yaşlı",      idle1 = 845397899,  idle2 = 845400520,  walk = 845403856,  run = 845386501,  jump = 845398858,  fall = 845396048,  climb = 845392038,  swim = 845401742,  swimidle = 845403127},
        {name = "Stilist",    idle1 = 616136790,  idle2 = 616138447,  walk = 616146177,  run = 616140816,  jump = 616139451,  fall = 616134815,  climb = 616133594,  swim = 616143378,  swimidle = 616144772},
        {name = "Neşeli",     idle1 = 910004836,  idle2 = 910009958,  walk = 910034870,  run = 910025107,  jump = 910016857,  fall = 910001910,  climb = 909997997,  swim = 910028158,  swimidle = 910030921},
        {name = "Çizgi Film", idle1 = 742637544,  idle2 = 742638445,  walk = 742640026,  run = 742638842,  jump = 742637942,  fall = 742637151,  climb = 742636889},
        {name = "Sinsi",      idle1 = 1132473842, idle2 = 1132477671, walk = 1132510133, run = 1132494274, jump = 1132489853, fall = 1132469004, climb = 1132461372, swim = 1132500520, swimidle = 1132506407},
    }
    -- {Animate içindeki klasör, Animation adı, paket alanı}
    local MAP = {
        {"idle", "Animation1", "idle1"}, {"idle", "Animation2", "idle2"},
        {"walk", "WalkAnim", "walk"}, {"run", "RunAnim", "run"},
        {"jump", "JumpAnim", "jump"}, {"fall", "FallAnim", "fall"},
        {"climb", "ClimbAnim", "climb"}, {"swim", "Swim", "swim"}, {"swimidle", "SwimIdle", "swimidle"},
    }

    local selected = nil
    local originals = setmetatable({}, {__mode = "k"})
    local function aid(id) return "http://www.roblox.com/asset/?id=" .. tostring(id) end

    local function refresh(animate, hum)
        pcall(function()
            animate.Disabled = true
            local animator = hum:FindFirstChildOfClass("Animator")
            if animator then
                for _, t in ipairs(animator:GetPlayingAnimationTracks()) do t:Stop(0) end
            end
            task.wait()
            animate.Disabled = false
        end)
    end

    -- pack = nil  =>  oyunun orijinal animasyonlarını geri yükle
    local function applyToChar(ch, pack)
        local animate = ch and ch:FindFirstChild("Animate")
        local hum = ch and ch:FindFirstChildOfClass("Humanoid")
        if not (animate and hum) then return false end
        for _, m in ipairs(MAP) do
            local folder = animate:FindFirstChild(m[1])
            local a = folder and folder:FindFirstChild(m[2])
            if a and a:IsA("Animation") then
                if originals[a] == nil then originals[a] = a.AnimationId end
                if pack then
                    if pack[m[3]] then a.AnimationId = aid(pack[m[3]]) end
                else
                    a.AnimationId = originals[a]
                end
            end
        end
        refresh(animate, hum)
        return true
    end

    -- Paketin ana animasyonları (duruş + yürüme) gerçekten yükleniyor mu? İkisi de yüklenmezse uygulama (T-pose olmasın).
    local function packLoads(pack)
        local status, insts = {}, {}
        for _, key in ipairs({"idle1", "walk", "jump"}) do
            if pack[key] then
                local a = Instance.new("Animation")
                a.AnimationId = aid(pack[key])
                insts[#insts + 1] = a
                status[key] = a.AnimationId
            end
        end
        local result = {}
        pcall(function()
            ContentProvider:PreloadAsync(insts, function(id, st) result[id] = (st == Enum.AssetFetchStatus.Success) end)
        end)
        for _, a in ipairs(insts) do a:Destroy() end
        local idleOk = result[status.idle1] ~= false
        local walkOk = result[status.walk] ~= false
        return idleOk or walkOk
    end

    local function selectPack(pack)
        local ch = LocalPlayer.Character
        local hum = ch and ch:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        if hum.RigType ~= Enum.HumanoidRigType.R15 then
            notify("Animasyon", "Bu paketler sadece R15 karakterlerde çalışır.", 3)
            return
        end
        task.spawn(function()
            if not packLoads(pack) then
                notify("Animasyon", pack.name .. " paketi yüklenemedi, değiştirilmedi.", 3)
                return
            end
            if applyToChar(LocalPlayer.Character, pack) then
                selected = pack
                Settings.AnimPack = pack.name
                saveConfig()
                notify("Animasyon", pack.name .. " paketi aktif! (Respawn olsan da korunur)", 3)
            else
                notify("Animasyon", "Karakterde Animate betiği bulunamadı.", 3)
            end
        end)
    end

    local function resetPack()
        selected = nil
        Settings.AnimPack = nil
        saveConfig()
        if applyToChar(LocalPlayer.Character, nil) then
            notify("Animasyon", "Orijinal animasyonlar geri yüklendi.", 2)
        end
    end

    bind(LocalPlayer.CharacterAdded, function(ch)
        if not selected then return end
        task.spawn(function()
            ch:WaitForChild("Animate", 8)
            task.wait(0.8)
            if selected then applyToChar(ch, selected) end
        end)
    end)
    PX.onLock[#PX.onLock + 1] = function()
        if selected then
            -- premium kilitlenirse animasyonu geri al ama kayıtlı seçimi silme
            local keep = Settings.AnimPack
            resetPack()
            Settings.AnimPack = keep
            saveConfig()
        end
    end

    -- Script açılınca kayıtlı animasyon paketini otomatik uygula
    if Settings.AnimPack then
        task.spawn(function()
            local t0 = os.clock()
            while alive and not PX.unlocked and os.clock() - t0 < 90 do task.wait(1) end
            if not (alive and PX.unlocked) then return end
            local ch = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
            ch:WaitForChild("Animate", 10)
            task.wait(1)
            for _, pk in ipairs(PACKS) do
                if pk.name == Settings.AnimPack then
                    if applyToChar(LocalPlayer.Character, pk) then selected = pk end
                    break
                end
            end
        end)
    end

    PX.infoCard(PremiumPage, trText("🎭  Tam Animasyon Paketleri"),
        "Duruş, yürüme, koşma, zıplama, düşme, tırmanma ve yüzme animasyonları tek tıkla birlikte değişir. Sadece R15 karakterlerde çalışır.", 72)

    local header, headerSt = baseRow(PremiumPage, "TextButton", 42)
    rowLabel(header, "🎭  Animasyon Paketi Seç")
    local arrow = new("TextLabel", {
        Size = UDim2.new(0, 30, 1, 0), Position = UDim2.new(1, -36, 0, 0), BackgroundTransparency = 1,
        Text = "▾", Font = Enum.Font.GothamBold, TextSize = 18, TextColor3 = Color3.fromRGB(120, 134, 170), ZIndex = 4,
    }, header)
    hoverFx(header, headerSt)

    local PANEL_H = 300
    local content = new("ScrollingFrame", {
        LayoutOrder = nextOrder(PremiumPage),
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundTransparency = 1, BorderSizePixel = 0, ClipsDescendants = true,
        ScrollBarThickness = 3, ScrollBarImageColor3 = Color3.fromRGB(255, 42, 58),
        CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ZIndex = 3,
    }, PremiumPage)
    new("UIPadding", {PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4)}, content)
    new("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 3)}, content)

    local function guard(cb)
        return function()
            if not PX.unlocked then
                notify("Premium Gerekli", "Önce geçerli bir anahtar gir.", 3)
                return
            end
            cb()
        end
    end
    for _, pack in ipairs(PACKS) do
        createButton(content, "🎭  " .. pack.name, guard(function() selectPack(pack) end))
    end
    createButton(content, "♻️  Animasyonları Sıfırla (Orijinal)", guard(resetPack))

    local open = false
    bind(header.MouseButton1Click, function()
        if not PX.unlocked then
            notify("Premium Gerekli", "Önce geçerli bir anahtar gir.", 3)
            return
        end
        playClickSound()
        open = not open
        setText(arrow, open and "▴" or "▾")
        tween(content, 0.22, {Size = UDim2.new(1, 0, 0, open and PANEL_H or 0)})
    end)
end)()

PX.secHolders.outfit = createSection(PremiumPage, "👑  PREMİUM KIYAFET DEĞİŞTİRİCİ")

    -- Başka bir kullanıcının görünümünü kuşan
    do
        -- Sağdaki dönen karakter önizlemesi (fareyle üzerine gelinen oyuncuyu gösterir)
        local hoverTok, shownP = 0, nil
        local function viewportOk()
            local cam = MenuCharViewport.CurrentCamera
            return MenuCharViewport:FindFirstChildOfClass("Model") ~= nil
                and cam ~= nil and cam.Parent == MenuCharViewport
        end
        local function previewPlayer(plr)
            Settings.PlayerPreview(plr)
        end

        -- Mod: "global" = Roblox'taki herhangi biri, "server" = bu sunucudaki oyuncular
        local mode = "global"
        local modeRow = baseRow(PremiumPage, "Frame", 46)
        local modeBtns = {}
        local function makeModeBtn(key, text, xScale, xOff)
            local b = new("TextButton", {
                AnchorPoint = Vector2.new(0, 0.5),
                Position = UDim2.new(xScale, xOff, 0.5, 0),
                Size = UDim2.new(0.5, -14, 0, 32),
                BackgroundColor3 = Color3.fromRGB(28, 14, 20),
                AutoButtonColor = false, Text = text,
                Font = Enum.Font.GothamBold, TextSize = 12,
                TextColor3 = Color3.fromRGB(228, 233, 245), ZIndex = 4,
            }, modeRow)
            corner(b, 8)
            ctaFx(b, {radius = 8, colors = false})
            modeBtns[key] = {btn = b, st = stroke(b, 1, Color3.fromRGB(135, 40, 55), 0.3)}
            return b
        end
        makeModeBtn("global", "🌍  Genel Kullanıcı", 0, 10)
        makeModeBtn("server", "🖥️  Server İçinde", 0.5, 4)

        local _, nameBox, nameLbl = PX.inputRow(PremiumPage, "Genel Kullanıcı", "Roblox kullanıcı adı yaz")
        nameLbl.TextSize = 12
        nameLbl.TextWrapped = true
        nameLbl.Size = UDim2.new(0, 80, 0, 36)
        nameLbl.Position = UDim2.new(0, 14, 0.5, -18)

        local listFrame = new("ScrollingFrame", {
            LayoutOrder = nextOrder(PremiumPage),
            Size = UDim2.new(1, 0, 0, 0),
            BackgroundColor3 = ROW_BG, BackgroundTransparency = 0.05,
            BorderSizePixel = 0, ScrollBarThickness = 3,
            ScrollBarImageColor3 = Color3.fromRGB(255, 42, 58),
            CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
            Visible = false, ZIndex = 3,
        }, PremiumPage)
        corner(listFrame, 12)
        stroke(listFrame, 1, ROW_STROKE, 0.32)
        new("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4)}, listFrame)
        new("UIPadding", {PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6),
            PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6)}, listFrame)

        local busy = false

        -- Varlığı (asset) yükle: önce InsertService, olmazsa game:GetObjects
        local function loadAsset(id)
            local model
            local ok = pcall(function()
                model = game:GetService("InsertService"):LoadAsset(id)
            end)
            if ok and model then return model end
            local ok2, objs = pcall(function() return game:GetObjects("rbxassetid://" .. id) end)
            if ok2 and objs and objs[1] then return objs[1] end
            return nil
        end

        -- Yedek yöntem: ApplyDescription çalışmazsa parçaları elle uygula
        local function manualApply(char, hum, desc)
            -- Vücut renkleri
            local bc = char:FindFirstChildOfClass("BodyColors")
            if not bc then bc = Instance.new("BodyColors") bc.Parent = char end
            bc.HeadColor3, bc.TorsoColor3 = desc.HeadColor, desc.TorsoColor
            bc.LeftArmColor3, bc.RightArmColor3 = desc.LeftArmColor, desc.RightArmColor
            bc.LeftLegColor3, bc.RightLegColor3 = desc.LeftLegColor, desc.RightLegColor

            -- Eski aksesuar ve kıyafetleri temizle
            for _, v in ipairs(char:GetChildren()) do
                if v:IsA("Accessory") or v:IsA("Shirt") or v:IsA("Pants") or v:IsA("ShirtGraphic") then
                    v:Destroy()
                end
            end

            local function addClothing(id, className)
                if not id or id == 0 then return end
                local m = loadAsset(id)
                local item = m and m:FindFirstChildWhichIsA(className, true)
                if item then item:Clone().Parent = char end
            end
            addClothing(desc.Shirt, "Shirt")
            addClothing(desc.Pants, "Pants")
            addClothing(desc.GraphicTShirt, "ShirtGraphic")

            local added = 0
            for _, info in ipairs(desc:GetAccessories(true)) do
                local m = loadAsset(info.AssetId)
                local acc = m and m:FindFirstChildWhichIsA("Accessory", true)
                if acc then
                    local okAdd = pcall(function() hum:AddAccessory(acc:Clone()) end)
                    if okAdd then added += 1 end
                end
            end

            -- Yüz
            if desc.Face and desc.Face ~= 0 then
                local head = char:FindFirstChild("Head")
                local m = loadAsset(desc.Face)
                local decal = m and m:FindFirstChildWhichIsA("Decal", true)
                if head and decal then
                    local old = head:FindFirstChildOfClass("Decal")
                    if old then old:Destroy() end
                    decal:Clone().Parent = head
                end
            end
            return added
        end

        local function countAcc(char)
            local n = 0
            for _, v in ipairs(char:GetChildren()) do
                if v:IsA("Accessory") then n += 1 end
            end
            return n
        end

        -- Kaynak modelden (aksesuar / kıyafet / renk) parçaları karakterine kopyala
        local function applyFromModel(char, hum, desc, src)
            local accs, cloths = {}, {}
            for _, v in ipairs(src:GetChildren()) do
                if v:IsA("Accessory") then
                    accs[#accs + 1] = v
                elseif v:IsA("Shirt") or v:IsA("Pants") or v:IsA("ShirtGraphic") or v:IsA("BodyColors") then
                    cloths[#cloths + 1] = v
                end
            end
            if #accs + #cloths == 0 then error("kaynakta aksesuar/kıyafet yok") end

            -- Yeni görünüm hazır: eskisini temizle
            for _, v in ipairs(char:GetChildren()) do
                if v:IsA("Accessory") or v:IsA("Shirt") or v:IsA("Pants")
                    or v:IsA("ShirtGraphic") or v:IsA("BodyColors") then
                    pcall(function() v:Destroy() end)
                end
            end

            for _, v in ipairs(cloths) do pcall(function() v:Clone().Parent = char end) end
            for _, v in ipairs(accs) do pcall(function() hum:AddAccessory(v:Clone()) end) end

            -- Yüz ve kafa şekli
            pcall(function()
                local rh, ch = src:FindFirstChild("Head"), char:FindFirstChild("Head")
                if rh and ch then
                    local rf = rh:FindFirstChildOfClass("Decal")
                    if rf then
                        local old = ch:FindFirstChildOfClass("Decal")
                        if old then old:Destroy() end
                        rf:Clone().Parent = ch
                    end
                    local rm = rh:FindFirstChildOfClass("SpecialMesh")
                    if rm then
                        local om = ch:FindFirstChildOfClass("SpecialMesh")
                        if om then om:Destroy() end
                        rm:Clone().Parent = ch
                    end
                end
            end)

            -- Vücut parçaları (renk, mesh, doku)
            for _, rp in ipairs(src:GetChildren()) do
                local cp = char:FindFirstChild(rp.Name)
                if cp and rp:IsA("BasePart") and cp:IsA("BasePart") then
                    pcall(function()
                        cp.Color = rp.Color
                        if rp:IsA("MeshPart") and cp:IsA("MeshPart") then
                            cp.MeshId = rp.MeshId
                            cp.TextureID = rp.TextureID
                        end
                    end)
                end
            end

            -- Boy / genişlik
            if desc then
                pcall(function()
                    local rs = {
                        BodyHeightScale = desc.HeightScale, BodyWidthScale = desc.WidthScale,
                        BodyDepthScale = desc.DepthScale, HeadScale = desc.HeadScale,
                    }
                    for name, val in pairs(rs) do
                        local nv = hum:FindFirstChild(name)
                        if nv then nv.Value = val end
                    end
                end)
            end
        end

        local function applyLook(userId, label, srcPlr)
            if busy then return end
            busy = true
            task.spawn(function()
                local errs, usedMethod = {}, nil
                local char = LocalPlayer.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")

                if not hum then
                    errs[#errs + 1] = "karakter/Humanoid yok"
                else
                    local desc
                    for i = 1, 3 do
                        local s, r = pcall(function()
                            return Players:GetHumanoidDescriptionFromUserId(userId)
                        end)
                        if s and r then desc = r break end
                        errs[#errs + 1] = "desc: " .. tostring(r)
                        task.wait(1)
                    end

                    local expected = 0
                    if desc then pcall(function() expected = #desc:GetAccessories(true) end) end
                    local function verified() return expected == 0 or countAcc(char) > 0 end

                    local steps = {
                        {"ApplyDescription", function()
                            assert(desc, "desc yok")
                            local s, e = pcall(function() hum:ApplyDescriptionReset(desc) end)
                            if not s then hum:ApplyDescription(desc) end
                        end},
                        {"CharacterAppearance", function()
                            local m = Players:GetCharacterAppearanceAsync(userId)
                            applyFromModel(char, hum, desc, m)
                            pcall(function() m:Destroy() end)
                        end},
                        {"CanlıKarakter", function()
                            assert(srcPlr and srcPlr.Character, "oyuncunun karakteri yüklü değil")
                            applyFromModel(char, hum, desc, srcPlr.Character)
                        end},
                        {"Model", function()
                            assert(desc, "desc yok")
                            local rig
                            pcall(function() rig = Players:CreateHumanoidModelFromDescription(desc, hum.RigType) end)
                            if not rig then rig = Players:CreateHumanoidModelFromUserId(userId) end
                            applyFromModel(char, hum, desc, rig)
                            pcall(function() rig:Destroy() end)
                        end},
                        {"LoadAsset", function()
                            assert(desc, "desc yok")
                            manualApply(char, hum, desc)
                        end},
                    }

                    for _, step in ipairs(steps) do
                        local s, e = pcall(step[2])
                        if s and verified() then
                            usedMethod = step[1]
                            break
                        end
                        errs[#errs + 1] = step[1] .. ": " .. (s and "aksesuar eklenmedi" or tostring(e))
                    end

                    -- Oyun aksesuarları geri siliyor mu?
                    if usedMethod and expected > 0 then
                        task.wait(1.5)
                        if countAcc(char) == 0 then
                            errs[#errs + 1] = "oyun aksesuarları siliyor"
                            usedMethod = nil
                        end
                    end
                end

                busy = false
                if usedMethod then
                    print("[EZRAGOX] Yöntem: " .. usedMethod .. " | Aksesuar: " .. countAcc(char))
                    notify("Görünüm Kuşanıldı 👕", label .. " görünümü uygulandı.", 4)
                else
                    warn("[EZRAGOX] Görünüm hataları:\n" .. table.concat(errs, "\n"))
                    notify("Kuşanılamadı", tostring(errs[#errs] or "bilinmiyor"):sub(1, 110), 6)
                end
            end)
        end
        local selectedPlr = nil
        local thumbCache = {}
        local rowRefs = {}
        local applyBtn

        local function shownMatches()
            local f = string.lower((nameBox.Text or ""):gsub("%s", "") )
            local out = {}
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer then
                    local n, d = string.lower(plr.Name), string.lower(plr.DisplayName)
                    if f == "" or n:sub(1, #f) == f or d:sub(1, #f) == f
                        or n:find(f, 1, true) or d:find(f, 1, true) then
                        out[#out + 1] = plr
                    end
                end
            end
            return out
        end

        local function updateApplyLabel()
            local l = applyBtn and applyBtn:FindFirstChildOfClass("TextLabel")
            if not l then return end
            l.TextTruncate = Enum.TextTruncate.AtEnd
            if mode == "server" and selectedPlr then
                setText(l, "👕  Uygula  →  " .. selectedPlr.DisplayName .. " (@" .. selectedPlr.Name .. ")")
            elseif mode == "server" then
                setText(l, "👕  Seçilen Oyuncuyu Kopyala")
            else
                setText(l, "👕  Karakteri Komple Kopyala  (Saç • Üst • Alt • Aksesuar)")
            end
        end

        local function applySelectionStyles()
            for plr, r in pairs(rowRefs) do
                local sel = (plr == selectedPlr)
                if r.btn.Parent then
                    r.btn.BackgroundColor3 = sel and Color3.fromRGB(70, 14, 28) or Color3.fromRGB(28, 14, 20)
                    r.st.Color = sel and Color3.fromRGB(255, 42, 58) or Color3.fromRGB(135, 40, 55)
                    r.st.Transparency = sel and 0.05 or 0.55
                    r.mark.Visible = sel
                end
            end
        end

        local function wantListVisible() return mode == "server" and PX.unlocked end
        bind(listFrame:GetPropertyChangedSignal("Visible"), function()
            local want = wantListVisible()
            if listFrame.Visible ~= want then listFrame.Visible = want end
        end)

        local function refreshList()
            previewPlayer(nil)
            table.clear(rowRefs)
            for _, ch in ipairs(listFrame:GetChildren()) do
                if ch:IsA("TextButton") or ch:IsA("TextLabel") then ch:Destroy() end
            end
            if mode ~= "server" then
                listFrame.Visible = false
                listFrame.Size = UDim2.new(1, 0, 0, 0)
                previewPlayer(nil)
                return
            end

            local matches = shownMatches()
            if selectedPlr and not selectedPlr.Parent then selectedPlr = nil end

            if #matches == 0 then
                new("TextLabel", {
                    Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1,
                    Text = "Eşleşen oyuncu yok", Font = Enum.Font.GothamMedium, TextSize = 12,
                    TextColor3 = Color3.fromRGB(150, 163, 195), ZIndex = 4,
                }, listFrame)
            end

            for _, plr in ipairs(matches) do
                local isSel = (plr == selectedPlr)
                local pBtn = new("TextButton", {
                    Size = UDim2.new(1, 0, 0, 36),
                    BackgroundColor3 = isSel and Color3.fromRGB(70, 14, 28) or Color3.fromRGB(28, 14, 20),
                    BackgroundTransparency = 0.1, AutoButtonColor = false, Text = "", ZIndex = 4,
                }, listFrame)
                corner(pBtn, 8)
                ctaFx(pBtn, {radius = 8, colors = false})
                local pst = stroke(pBtn, 1, isSel and Color3.fromRGB(255, 42, 58) or Color3.fromRGB(135, 40, 55),
                    isSel and 0.05 or 0.55)

                local avImg = new("ImageLabel", {
                    Position = UDim2.new(0, 4, 0, 2), Size = UDim2.new(0, 32, 0, 32),
                    BackgroundTransparency = 1, Image = thumbCache[plr.UserId] or "", ZIndex = 5,
                }, pBtn)
                pill(avImg)
                if not thumbCache[plr.UserId] then
                    task.spawn(function()
                        local ok, thumb = pcall(function()
                            return Players:GetUserThumbnailAsync(plr.UserId,
                                Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
                        end)
                        if ok and thumb then
                            thumbCache[plr.UserId] = thumb
                            if avImg.Parent then avImg.Image = thumb end
                        end
                    end)
                end

                new("TextLabel", {
                    Position = UDim2.new(0, 44, 0, 0), Size = UDim2.new(1, -70, 1, 0),
                    BackgroundTransparency = 1, Text = plr.DisplayName .. " (@" .. plr.Name .. ")",
                    TextColor3 = Color3.new(1, 1, 1), TextSize = 12, Font = Enum.Font.GothamMedium,
                    TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
                    ZIndex = 5,
                }, pBtn)
                local mark = new("TextLabel", {
                    AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0),
                    Size = UDim2.new(0, 18, 0, 18), BackgroundTransparency = 1, Text = "✓",
                    Font = Enum.Font.GothamBold, TextSize = 14,
                    TextColor3 = Color3.fromRGB(255, 112, 122), ZIndex = 5, Visible = isSel,
                }, pBtn)
                rowRefs[plr] = {btn = pBtn, st = pst, mark = mark}

                -- Üzerine gelince sağdaki dönen karakter bu oyuncu olur
                pBtn.MouseEnter:Connect(function()
                    tween(pBtn, 0.12, {BackgroundColor3 = Color3.fromRGB(48, 12, 22), BackgroundTransparency = 0})
                    tween(pst, 0.12, {Color = Color3.fromRGB(255, 42, 58), Transparency = 0.1})
                    previewPlayer(plr)
                end)
                pBtn.MouseLeave:Connect(function()
                    local sel = (plr == selectedPlr)
                    tween(pBtn, 0.18, {
                        BackgroundColor3 = sel and Color3.fromRGB(70, 14, 28) or Color3.fromRGB(28, 14, 20),
                        BackgroundTransparency = 0.1,
                    })
                    tween(pst, 0.18, {
                        Color = sel and Color3.fromRGB(255, 42, 58) or Color3.fromRGB(135, 40, 55),
                        Transparency = sel and 0.05 or 0.55,
                    })
                    previewPlayer(nil)
                end)
                pBtn.MouseButton1Click:Connect(function()
                    playClickSound()
                    selectedPlr = plr
                    updateApplyLabel()
                    applySelectionStyles()
                    previewPlayer(nil)   -- seçince sağdaki karakter tekrar benim karakterime döner
                end)
            end

            listFrame.Visible = wantListVisible()
            listFrame.Size = UDim2.new(1, 0, 0, math.min(math.max(#matches, 1) * 40 + 12, 176))
        end

        local function setMode(m)
            mode = m
            for key, d in pairs(modeBtns) do
                local on = (key == m)
                tween(d.btn, 0.16, {BackgroundColor3 = on and Color3.fromRGB(140, 20, 36) or Color3.fromRGB(28, 14, 20)})
                tween(d.st, 0.16, {
                    Color = on and Color3.fromRGB(255, 42, 58) or Color3.fromRGB(135, 40, 55),
                    Transparency = on and 0.05 or 0.3,
                })
            end
            if m == "server" then
                setText(nameLbl, "Server İçinde")
                setPlaceholder(nameBox, "İsmin başını yaz, liste süzülür")
            else
                setText(nameLbl, "Genel Kullanıcı")
                setPlaceholder(nameBox, "Roblox kullanıcı adı yaz")
            end
            updateApplyLabel()
            refreshList()
        end

        bind(modeBtns.global.btn.MouseButton1Click, function() playClickSound() setMode("global") end)
        bind(modeBtns.server.btn.MouseButton1Click, function() playClickSound() setMode("server") end)
        bind(nameBox:GetPropertyChangedSignal("Text"), function()
            if mode == "server" then refreshList() end
        end)
        bind(Players.PlayerAdded, function() if mode == "server" then refreshList() end end)
        bind(Players.PlayerRemoving, function(plr)
            if plr == selectedPlr then selectedPlr = nil updateApplyLabel() end
            task.defer(function() if mode == "server" then refreshList() end end)
        end)
        bind(PremiumPage:GetPropertyChangedSignal("Visible"), function()
            if not PremiumPage.Visible then previewPlayer(nil) end
        end)

        applyBtn = PX.button("👕  Karakteri Komple Kopyala  (Saç • Üst • Alt • Aksesuar)", function()
            if mode == "server" then
                local target = selectedPlr
                if not (target and target.Parent) then
                    local m = shownMatches()
                    if #m == 1 then
                        target = m[1]
                    else
                        notify("Oyuncu Seçilmedi", "Listeden bir oyuncu seç (ya da adını yaz).", 3)
                        return
                    end
                end
                applyLook(target.UserId, target.Name, target)
            else
                local name = nameBox.Text:gsub("%s", "")
                if name == "" then
                    notify("Kullanıcı Adı Boş", "Önce bir Roblox kullanıcı adı yaz.", 3)
                    return
                end
                task.spawn(function()
                    local id = PX.resolveUserId(name)
                    if id then
                        applyLook(id, name)
                    else
                        notify("Kullanıcı Bulunamadı", name, 3)
                    end
                end)
            end
        end)
        PX.button("♻️  Kendi Görünümüme Dön", function()
            applyLook(LocalPlayer.UserId, "Kendi")
        end)

        setMode("global")
    end

    createSection(PremiumPage, "👑  PREMİUM OTO TOPLAYICI")

    -- Haritada spawn olan para / altın / gem gibi şeyleri otomatik toplar
    do
        local enabled, runId = false, 0
        local cands = {}          -- [part] = {tries, nextAt, touched}
        local pending = {}        -- yeni eklenen ve henüz incelenmemiş nesneler
        local collected = 0
        local speedLevel = 3      -- 1 = en yavaş/temkinli, 10 = en hızlı

        local BASE_WORDS = {
            "coin", "gold", "cash", "money", "gem", "para", "altin", "altın", "diamond",
            "crystal", "orb", "token", "loot", "collect", "pickup", "dollar", "reward",
            "currency", "treasure", "bill", "nugget",
        }
        local DENY_WORDS = {
            "shop", "store", "sell", "buy", "upgrade", "rebirth", "gate", "door",
            "teleport", "button", "portal",
        }

        local _, customBox = PX.inputRow(PremiumPage, "Özel İsim", "örn: Coin, Gold  (boş = otomatik bul)")

        local function hasWord(name, words)
            for _, w in ipairs(words) do
                if string.find(name, w, 1, true) then return true end
            end
            return false
        end

        local function customWords()
            local t = {}
            for w in string.gmatch(string.lower(customBox.Text or ""), "[^,%s]+") do
                t[#t + 1] = w
            end
            return #t > 0 and t or nil
        end

        local function isCharPart(part)
            local m = part:FindFirstAncestorOfClass("Model")
            while m do
                if Players:GetPlayerFromCharacter(m) then return true end
                local par = m.Parent
                m = par and par:FindFirstAncestorOfClass("Model") or nil
            end
            return false
        end

        local function nameMatches(part, custom)
            if not custom then
                local own = string.lower(part.Name)
                local par = part.Parent and string.lower(part.Parent.Name) or ""
                if hasWord(own, DENY_WORDS) or hasWord(par, DENY_WORDS) then return false end
            end
            local words = custom or BASE_WORDS
            local node, depth = part, 0
            while node and node ~= workspace and depth < 4 do
                if hasWord(string.lower(node.Name), words) then return true end
                node = node.Parent
                depth = depth + 1
            end
            return false
        end

        local function considerPart(part, custom, target)
            if target[part] or not part:IsA("BasePart") or part:IsA("Terrain") then return end
            if isCharPart(part) then return end
            if not nameMatches(part, custom) then return end
            local interactive = part:FindFirstChildWhichIsA("TouchTransmitter")
                or part:FindFirstChildWhichIsA("ProximityPrompt", true)
                or part:FindFirstChildWhichIsA("ClickDetector", true)
            -- Otomatik modda sadece etkileşimli (dokunulabilir/prompt'lu) parçalar alınır
            if not custom and not interactive then return end
            target[part] = {tries = 0, nextAt = 0, touched = false}
        end

        local function enqueue(inst)
            if #pending > 5000 then return end
            if inst:IsA("BasePart") then
                pending[#pending + 1] = inst
            elseif inst:IsA("TouchTransmitter") or inst:IsA("ProximityPrompt") or inst:IsA("ClickDetector") then
                local part = inst:FindFirstAncestorWhichIsA("BasePart")
                if part then pending[#pending + 1] = part end
            end
        end

        local function processPending(custom)
            local n = 0
            while #pending > 0 and n < 300 do
                local inst = table.remove(pending)
                if inst and inst.Parent then pcall(considerPart, inst, custom, cands) end
                n = n + 1
            end
        end

        -- Tüm haritayı tara (donmasın diye parça parça)
        local function scanInto(target, custom)
            local count = 0
            local list = workspace:GetDescendants()
            for i, inst in ipairs(list) do
                if inst:IsA("BasePart") then
                    local before = target[inst]
                    pcall(considerPart, inst, custom, target)
                    if not before and target[inst] then count = count + 1 end
                end
                if i % 1500 == 0 then task.wait() end
            end
            return count
        end

        bind(workspace.DescendantAdded, function(inst)
            if enabled then enqueue(inst) end
        end)

        local function interact(part, hrp)
            local used = false
            local prompt = part:FindFirstChildWhichIsA("ProximityPrompt", true)
            if prompt and type(fireproximityprompt) == "function" then
                pcall(fireproximityprompt, prompt)
                used = true
            end
            local cd = part:FindFirstChildWhichIsA("ClickDetector", true)
            if cd and type(fireclickdetector) == "function" then
                pcall(fireclickdetector, cd)
                used = true
            end
            if type(firetouchinterest) == "function" and part:FindFirstChildWhichIsA("TouchTransmitter") then
                pcall(function()
                    firetouchinterest(hrp, part, 0)
                    firetouchinterest(hrp, part, 1)
                end)
                used = true
            end
            return used
        end

        -- En yakın hazır parçayı seç (hepsini birden değil, tek tek gidilecek)
        local function pickNearest(hrp, now)
            local best, bestInfo, bestD
            local pos = hrp.Position
            for part, info in pairs(cands) do
                if not part.Parent then
                    if info.touched then collected = collected + 1 end
                    cands[part] = nil
                elseif now >= info.nextAt and part.CanTouch ~= false then
                    local d = (part.Position - pos).Magnitude
                    if not bestD or d < bestD then best, bestInfo, bestD = part, info, d end
                end
            end
            return best, bestInfo
        end

        -- Tek parça: doğrudan paranın üstüne ışınlan (süzülme yok), kısa bekle
        local function pickupOne(part, info, hrp)
            info.tries = info.tries + 1
            info.touched = true
            pcall(function()
                hrp.CFrame = CFrame.new(part.Position)
                hrp.AssemblyLinearVelocity = Vector3.zero
                hrp.AssemblyAngularVelocity = Vector3.zero
            end)
            -- Önce fiziksel temasın gerçekleşmesine izin ver
            RunService.Heartbeat:Wait()
            RunService.Heartbeat:Wait()
            -- Yetmediyse yedek etkileşim (artık paranın tam üstündeyken)
            if part.Parent then interact(part, hrp) end
            task.wait(0.2 + math.random() * 0.15)
            if info.tries >= 3 and part.Parent then
                info.tries = 0
                info.nextAt = os.clock() + 20   -- toplanamayanı 20 sn beklet
            else
                info.nextAt = os.clock() + 1
            end
        end

        local function collectLoop(myRun)
            local homeCF, idleSince = nil, nil
            while enabled and alive and myRun == runId do
                local char = LocalPlayer.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if hrp and hum and hum.Health > 0 then
                    processPending(customWords())
                    local part, info = pickNearest(hrp, os.clock())
                    if part then
                        idleSince = nil
                        if not homeCF then homeCF = hrp.CFrame end
                        pickupOne(part, info, hrp)
                        -- Hız ayarına göre bekle (hafif rastgele sapmayla)
                        local delay = 2.5 - (speedLevel - 1) * (2.2 / 9)
                        task.wait(delay * (0.8 + math.random() * 0.4))
                    else
                        -- Toplanacak kalmadıysa başladığım yere bir kez dön
                        if homeCF then
                            idleSince = idleSince or os.clock()
                            if os.clock() - idleSince > 1.2 then
                                pcall(function()
                                    hrp.CFrame = homeCF
                                    hrp.AssemblyLinearVelocity = Vector3.zero
                                end)
                                homeCF, idleSince = nil, nil
                            end
                        end
                        task.wait(0.25)
                    end
                else
                    homeCF, idleSince = nil, nil
                    task.wait(0.5)
                end
            end
            -- Kapatıldıysa başladığım yere dön
            if homeCF and not enabled then
                local c = LocalPlayer.Character
                local h = c and c:FindFirstChild("HumanoidRootPart")
                if h then pcall(function() h.CFrame = homeCF end) end
            end
        end

        PX.toggle("💰  Otomatik Para / Altın Topla  (Tüm Harita)", function(v)
            enabled = v
            runId = runId + 1
            local myRun = runId
            if v then
                collected = 0
                table.clear(cands)
                table.clear(pending)
                local hasFns = type(firetouchinterest) == "function"
                notify("Oto Toplayıcı", hasFns and "En yakın paradan başlayıp tek tek toplanacak."
                    or "Executor dokunma fonksiyonu yok: paranın üstüne ışınlanarak toplanacak.", 3)
                task.spawn(function()
                    local n = scanInto(cands, customWords())
                    if enabled and myRun == runId and n == 0 then
                        notify("Para Bulunamadı", "Şu an eşleşen yok. Yeni spawn olanlar otomatik alınır. İstersen 'Özel İsim' yaz.", 5)
                    end
                end)
                task.spawn(collectLoop, myRun)
            else
                table.clear(cands)
                table.clear(pending)
                notify("Oto Toplayıcı Kapandı", collected .. " parça toplandı.", 3)
            end
        end)

        PX.slider("⚡  Toplama Hızı  (düşük = daha temkinli)", 1, 10, 3, function(v)
            speedLevel = v
        end)

        bind(customBox.FocusLost, function()
            if not enabled then return end
            runId = runId + 1
            local myRun = runId
            table.clear(cands)
            table.clear(pending)
            task.spawn(function() scanInto(cands, customWords()) end)
            task.spawn(collectLoop, myRun)
        end)

        PX.button("🔍  Haritadaki Paraları Tara  (Kaç Tane Var?)", function()
            task.spawn(function()
                local tmp = {}
                local total = scanInto(tmp, customWords())
                if total == 0 then
                    notify("Tarama Bitti", "Hiç bulunamadı. 'Özel İsim' kutusuna paranın adını yaz (örn: Coin).", 5)
                    return
                end
                local groups = {}
                for part in pairs(tmp) do groups[part.Name] = (groups[part.Name] or 0) + 1 end
                local arr = {}
                for name, c in pairs(groups) do arr[#arr + 1] = {name, c} end
                table.sort(arr, function(a, b) return a[2] > b[2] end)
                local out = {}
                for i = 1, math.min(#arr, 4) do out[#out + 1] = arr[i][1] .. " ×" .. arr[i][2] end
                print("[EZRAGOX] Tarama sonucu:")
                for _, a in ipairs(arr) do print("  " .. a[1] .. " ×" .. a[2]) end
                notify("Tarama: " .. total .. " parça", table.concat(out, "  •  "), 6)
            end)
        end)
    end

    PX.secHolders.tag = createSection(PremiumPage, "👑  PREMİUM SAHTE TAG & RGB İSİM")

    -- Sahte rütbe yazısı + RGB isim (yalnızca senin ekranında görünür, sunucuyu etkilemez)
    do
        -- Oyundaki gerçek rütbe yazısı gibi: parantezsiz, ismin altında, sarı-yeşil, siyah konturlu
        local TAGS = {
            "Mod", "Admin", "HeadAdmin", "Owner", "SeniorMod", "SeniorAdmin",
            "SeniorLeader", "Yardımcı", "Gear", "Denetleyici",
        }
        local TAG_COLOR = Color3.fromRGB(205, 215, 45)
        local tagOn, rgbOn, tagIdx, rgbSpeed, tagY = false, false, 6, 5, 22
        do local ti = tonumber(Settings.TagIdx); if ti and TAGS[ti] then tagIdx = ti end end
        local tagGui, tagLbl = nil, nil
        local nameGui, nameLbl = nil, nil            -- oyunun kendi isim yazısı bulunamazsa kullanılan yedek
        local gameLabels, origColors, lastScan = {}, {}, 0
        local origHum, origDisplay = nil, nil

        local function destroyTag()
            if tagGui then pcall(function() tagGui:Destroy() end) end
            tagGui, tagLbl = nil, nil
        end
        local function restoreName()
            for lbl, col in pairs(origColors) do
                if lbl and lbl.Parent then pcall(function() lbl.TextColor3 = col end) end
            end
            origColors, gameLabels = {}, {}
            if nameGui then pcall(function() nameGui:Destroy() end) end
            nameGui, nameLbl = nil, nil
            if origHum and origHum.Parent and origDisplay then
                pcall(function() origHum.DisplayDistanceType = origDisplay end)
            end
            origHum, origDisplay = nil, nil
        end

        local function buildTag(char)
            destroyTag()
            local head = char:FindFirstChild("Head")
            if not head then return end
            tagGui = new("BillboardGui", {
                Name = "EZRAGOX_FakeTag", Adornee = head, AlwaysOnTop = true,
                Size = UDim2.new(0, 240, 0, 30), StudsOffset = Vector3.new(0, tagY / 10, 0),
                MaxDistance = 1000,
            }, head)
            tagLbl = new("TextLabel", {
                BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0),
                Font = Enum.Font.GothamBlack, TextSize = 22, Text = "",
                TextColor3 = TAG_COLOR, TextStrokeColor3 = Color3.new(0, 0, 0),
                TextStrokeTransparency = 0,
            }, tagGui)
        end

        -- Oyunun kendi isim yazısını bul (başındaki BillboardGui içindeki isim etiketi)
        local function scanNameLabels(char)
            gameLabels = {}
            for _, d in ipairs(char:GetDescendants()) do
                if d:IsA("TextLabel") and d ~= tagLbl and d ~= nameLbl
                    and (d.Text == LocalPlayer.Name or d.Text == LocalPlayer.DisplayName)
                    and d:FindFirstAncestorOfClass("BillboardGui") then
                    gameLabels[#gameLabels + 1] = d
                    if origColors[d] == nil then origColors[d] = d.TextColor3 end
                end
            end
        end

        local function buildFallbackName(char)
            local head = char:FindFirstChild("Head")
            if not head then return end
            if nameGui then pcall(function() nameGui:Destroy() end) end
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum and not origHum then
                origHum, origDisplay = hum, hum.DisplayDistanceType
                hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
            end
            nameGui = new("BillboardGui", {
                Name = "EZRAGOX_RGBName", Adornee = head, AlwaysOnTop = true,
                Size = UDim2.new(0, 240, 0, 30), StudsOffset = Vector3.new(0, tagY / 10 + 1.2, 0),
                MaxDistance = 1000,
            }, head)
            nameLbl = new("TextLabel", {
                BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0),
                Font = Enum.Font.GothamBlack, TextSize = 22, Text = LocalPlayer.DisplayName,
                TextColor3 = Color3.new(1, 1, 1), TextStrokeColor3 = Color3.new(0, 0, 0),
                TextStrokeTransparency = 0,
            }, nameGui)
        end

        bind(RunService.Heartbeat, function()
            if not (tagOn or rgbOn) then return end
            local char = LocalPlayer.Character
            if not char then return end
            local t = os.clock()

            if tagOn then
                if not tagGui or tagGui.Parent == nil or not tagGui:IsDescendantOf(char) then
                    buildTag(char)
                end
                if tagLbl then
                    tagLbl.Text = TAGS[tagIdx]
                    tagGui.StudsOffset = Vector3.new(0, tagY / 10, 0)
                end
            end

            if rgbOn then
                if t - lastScan > 1 then
                    lastScan = t
                    scanNameLabels(char)
                end
                local col = Color3.fromHSV((t * rgbSpeed * 0.07) % 1, 1, 1)
                local any = false
                for _, lbl in ipairs(gameLabels) do
                    if lbl.Parent then
                        lbl.TextColor3 = col
                        any = true
                    end
                end
                if not any then
                    if not nameGui or nameGui.Parent == nil or not nameGui:IsDescendantOf(char) then
                        buildFallbackName(char)
                    end
                    if nameLbl then
                        nameLbl.TextColor3 = col
                        nameGui.StudsOffset = Vector3.new(0, tagY / 10 + 1.2, 0)
                    end
                end
            end
        end)

        PX.toggle("🏷️  Sahte Rütbe Yazısı Göster", function(v)
            tagOn = v
            if v then
                notify("Sahte Rütbe", TAGS[tagIdx] .. " aktif! (Sadece senin ekranında görünür)", 3)
            else
                destroyTag()
            end
        end)

        -- Rütbe menüsü: başlığa basmadıkça liste gözükmez; basınca alta doğru sıralanır
        do
            local mHeader, mSt = baseRow(PremiumPage, "TextButton", 42)
            rowLabel(mHeader, "🏷️  Rütbe Menüsü")
            local mArrow = new("TextLabel", {
                Size = UDim2.new(0, 30, 1, 0), Position = UDim2.new(1, -36, 0, 0), BackgroundTransparency = 1,
                Text = "▾", Font = Enum.Font.GothamBold, TextSize = 18, TextColor3 = Color3.fromRGB(120, 134, 170), ZIndex = 4,
            }, mHeader)
            hoverFx(mHeader, mSt)

            local mBody = new("Frame", {
                LayoutOrder = nextOrder(PremiumPage), Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, BorderSizePixel = 0,
                Visible = false, ZIndex = 3,
            }, PremiumPage)
            new("UIPadding", {PaddingLeft = UDim.new(0, 12), PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 2)}, mBody)
            new("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 3)}, mBody)
            PX.collapsibles[#PX.collapsibles + 1] = mBody

            for i, name in ipairs(TAGS) do
                createButton(mBody, "🏷️  Rütbe: " .. name, function()
                    if not PX.unlocked then return end
                    tagIdx = i
                    Settings.TagIdx = i
                    saveConfig()
                    notify("Rütbe Seçildi", name .. (tagOn and "" or "  —  Üstteki anahtarı aç."), 2)
                end)
            end
            -- Kaydırıcı sayfa kaydırmasını kilitlediği için önce sayfada oluşturulur, sonra menüye taşınır
            do
                local sBefore = snapshot(PremiumPage)
                createSlider(PremiumPage, "↕️  Yazı Yüksekliği  (isim altına denk getir)", 0, 60, 22, function(v)
                    if PX.unlocked then tagY = v end
                end)
                local moved = {}
                collectNew(PremiumPage, sBefore, moved)
                for _, r in ipairs(moved) do r.Parent = mBody end
            end

            local mOpen = false
            bind(mHeader.MouseButton1Click, function()
                if not PX.unlocked then return end
                playClickSound()
                mOpen = not mOpen
                mBody.Visible = mOpen
                setText(mArrow, mOpen and "▴" or "▾")
            end)
            PX.onLock[#PX.onLock + 1] = function()
                mOpen = false
                mBody.Visible = false
                setText(mArrow, "▾")
            end
        end

        PX.toggle("🌈  RGB İsim  (Renk Değiştiren Ad)", function(v)
            rgbOn = v
            if v then
                notify("RGB İsim", "İsmin renk değiştiriyor! (Sadece senin ekranında)", 3)
            else
                restoreName()
            end
        end)

        PX.slider("⚡  RGB Hızı", 1, 10, 5, function(v) rgbSpeed = v end)

        PX.onLock[#PX.onLock + 1] = function()
            tagOn, rgbOn = false, false
            destroyTag()
            restoreName()
        end
    end

    PX.secHolders.headless = createSection(PremiumPage, "👑  PREMİUM HEADLESS & KORBLOX")
    PX.infoCard(PremiumPage, trText("💀  Headless & Korblox"), "Headless: yalnızca gerçek karakter kafan ve yüzü görünmez olur; saç, şapka ve baş aksesuarların yerinde kalır. Korblox: sağ bacak silinir. Yalnızca senin ekranında görünür, diğer oyuncular görmez. Yeniden doğunca otomatik uygulanır; kapatınca eski görünüm geri gelir.", 96)

    do
        local KOR_R15 = {"RightUpperLeg", "RightLowerLeg", "RightFoot"}
        -- Headless Horseman görünümü: yalnızca karakterin gerçek Head parçası
        -- ve ona ait yüz decal/texture öğeleri gizlenir. Saç, şapka ve diğer
        -- Accessory nesnelerine kesinlikle dokunulmaz.
        local BODY = {
            HumanoidRootPart = true, UpperTorso = true, LowerTorso = true, Torso = true,
            LeftUpperArm = true, LeftLowerArm = true, LeftHand = true,
            RightUpperArm = true, RightLowerArm = true, RightHand = true,
            LeftUpperLeg = true, LeftLowerLeg = true, LeftFoot = true,
            RightUpperLeg = true, RightLowerLeg = true, RightFoot = true,
            ["Left Arm"] = true, ["Right Arm"] = true, ["Left Leg"] = true, ["Right Leg"] = true,
        }

        local headOn, korOn = false, false
        local visConn = nil
        local headFail, headErrShown = 0, false
        local headTargets, headChar, lastCollect = {}, nil, 0
        local saved = {
            head = setmetatable({}, {__mode = "k"}),
            kor = setmetatable({}, {__mode = "k"}),
        }

        -- Özelliği ilk değiştirmeden önce eski değerini hatırla (kapatınca geri yüklenir)
        local function setProp(kind, inst, prop, val)
            local t = saved[kind][inst]
            if not t then
                t = {}
                saved[kind][inst] = t
            end
            if t[prop] == nil then t[prop] = inst[prop] end
            if inst[prop] ~= val then inst[prop] = val end
        end

        local function restore(kind)
            for inst, props in pairs(saved[kind]) do
                for prop, val in pairs(props) do
                    pcall(function() inst[prop] = val end)
                end
            end
            saved[kind] = setmetatable({}, {__mode = "k"})
            if kind == "head" then headTargets, headChar = {}, nil end
        end

        ---------------------------------------------------------
        -- HEADLESS: Headless Horseman kafası gibi yalnızca gerçek kafa gizlenir
        ---------------------------------------------------------
        local function collectHead(char)
            local head = char:FindFirstChild("Head")
            local list, seen = {}, {}

            local function add(inst)
                if not seen[inst] then
                    seen[inst] = true
                    list[#list + 1] = inst
                end
            end

            if not head then return list end

            -- Head parçası MeshPart/Part olsa da yerel görünmezlik uygulanır.
            if head:IsA("BasePart") then add(head) end

            -- Yalnızca gerçek Head nesnesinin kendi yüz öğelerini al.
            -- Karakterin diğer çocuklarına ve Accessory nesnelerine girilmez.
            for _, d in ipairs(head:GetDescendants()) do
                if d:IsA("BasePart") or d:IsA("Decal") or d:IsA("Texture") then
                    add(d)
                end
            end

            return list
        end

        local function hideHead(char)
            local now = os.clock()
            if headChar ~= char or now - lastCollect > 0.25 then
                headChar, lastCollect = char, now
                headTargets = collectHead(char)
            end

            for i = 1, #headTargets do
                local target = headTargets[i]
                if target.Parent then
                    if target:IsA("BasePart") then
                        -- LocalTransparencyModifier yalnızca bu oyuncunun ekranında etkilidir.
                        setProp("head", target, "LocalTransparencyModifier", 1)
                        if target.LocalTransparencyModifier < 0.99 then
                            headFail = headFail + 1
                        end
                    elseif target:IsA("Decal") or target:IsA("Texture") then
                        setProp("head", target, "Transparency", 1)
                        if target.Transparency < 0.99 then
                            headFail = headFail + 1
                        end
                    end
                end
            end
        end

        ---------------------------------------------------------
        -- KORBLOX: sağ bacak silinir (görünmez olur)
        ---------------------------------------------------------
        local function hideLeg(char)
            for _, n in ipairs(KOR_R15) do
                local p = char:FindFirstChild(n)
                if p and p.Transparency ~= 1 then setProp("kor", p, "Transparency", 1) end
            end
            local r6 = char:FindFirstChild("Right Leg")
            if r6 and r6.Transparency ~= 1 then setProp("kor", r6, "Transparency", 1) end
        end

        -- Tek bağlantı: her karede uygular, yeniden doğma / oyunun sıfırlaması fark etmez
        local function refresh()
            if visConn then
                visConn:Disconnect()
                visConn = nil
            end
            if not (headOn or korOn) then return end
            headFail, headErrShown = 0, false
            visConn = RunService.RenderStepped:Connect(function()
                local char = LocalPlayer.Character
                if not char then return end
                if korOn then pcall(hideLeg, char) end
                if headOn then
                    local ok, err = pcall(hideHead, char)
                    if (not ok or headFail > 30) and not headErrShown then
                        headErrShown = true
                        notify("Headless", "Kafa gizlenemedi: " .. tostring(ok and "Transparency değişmiyor" or err), 5)
                    end
                end
            end)
            conns[#conns + 1] = visConn
        end

        PX.toggle("💀  Headless (Kafasız)", function(v)
            headOn = v
            if not v then restore("head") end
            refresh()
            if v then notify("Headless", "Aktif! Kafan ve yüzün görünmez oldu.", 2) end
        end)

        PX.toggle("🦴  Korblox (Sağ Bacak)", function(v)
            korOn = v
            if not v then restore("kor") end
            refresh()
            if v then notify("Korblox", "Aktif! Sağ bacağın silindi.", 2) end
        end)

        PX.onLock[#PX.onLock + 1] = function()
            headOn, korOn = false, false
            restore("head")
            restore("kor")
            refresh()
        end
    end

    createSection(PremiumPage, "👑  PREMİUM HİLECİ TESPİTİ")
    PX.infoCard(PremiumPage, trText("🚨  Hileci Tespiti"), "Fly, hız, noclip, spin ve yerin altına girme gibi diğer oyuncuların ekranında görünen hileleri algılar; hile yapan oyuncunun üstüne kırmızı HİLE yazar. ESP gibi sadece kişinin kendi ekranında çalışan hileler dışarıdan görülemez.", 84)

    -- Diğer oyuncuların sunucuya yansıyan hareketlerini izler.
    -- Etiket ScreenGui üzerinde çizilir: kamera/ekran genişletme efektinden etkilenmeden
    -- hedef karakterin başının üstünde kalır.
    do
        local SAMPLE = 0.15
        local FLAG_HOLD = 30
        local SHOW_REASON = true
        -- Birkaç ardışık örnekte doğrulama: kısa gecikmeyle yakalar, tek karelik sıçramaları ele.
        local NEED = {fly = 4, speed = 5, noclip = 4, spin = 3}
        local ORDER = {"fly", "speed", "noclip", "spin"}
        local REASON_TR = {fly = "Fly", speed = "Hız", noclip = "Noclip / Yer Altı", spin = "Spin"}
        local REASON_EN = {fly = "Fly", speed = "Speed", noclip = "Noclip / Underground", spin = "Spin"}
        local RED = Color3.fromRGB(255, 35, 35)

        local detOn, detGen = false, 0
        local det = {}
        local playerGui = LocalPlayer:WaitForChild("PlayerGui")
        local tagLayer
        local renderConn

        local function newCounters()
            return {fly = 0, speed = 0, noclip = 0, spin = 0}
        end
        local function isEN() return Settings.Language == "EN" end

        local function ensureLayer()
            if tagLayer and tagLayer.Parent then return tagLayer end
            tagLayer = Instance.new("ScreenGui")
            tagLayer.Name = "EZRAGOX_CheatTags"
            tagLayer.ResetOnSpawn = false
            tagLayer.IgnoreGuiInset = true
            tagLayer.DisplayOrder = 10000
            tagLayer.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
            tagLayer.Parent = playerGui
            return tagLayer
        end

        local function clearTag(st)
            if st.gui then pcall(function() st.gui:Destroy() end) end
            st.gui, st.lbl, st.sub = nil, nil, nil
        end

        local function clearAll()
            for _, st in pairs(det) do clearTag(st) end
            det = {}
            if tagLayer then pcall(function() tagLayer:Destroy() end) end
            tagLayer = nil
        end

        local function showTag(st)
            if st.gui and st.gui.Parent then
                st.lbl.Text = isEN() and "CHEAT" or "HİLE"
                if st.sub then
                    st.sub.Text = st.reasonKey and ((isEN() and REASON_EN or REASON_TR)[st.reasonKey]) or ""
                end
                return
            end

            local layer = ensureLayer()
            local root = Instance.new("Frame")
            root.Name = "EZRAGOX_CheatTag"
            root.BackgroundTransparency = 1
            root.AnchorPoint = Vector2.new(0.5, 1)
            root.Size = UDim2.fromOffset(190, SHOW_REASON and 52 or 32)
            root.Visible = false
            root.Parent = layer

            local lbl = Instance.new("TextLabel")
            lbl.BackgroundTransparency = 1
            lbl.Size = UDim2.new(1, 0, 0, 31)
            lbl.Text = isEN() and "CHEAT" or "HİLE"
            lbl.Font = Enum.Font.GothamBlack
            lbl.TextSize = 26
            lbl.TextColor3 = RED
            lbl.TextStrokeTransparency = 0
            lbl.TextStrokeColor3 = Color3.new(0, 0, 0)
            lbl.Parent = root

            local sub
            if SHOW_REASON then
                sub = Instance.new("TextLabel")
                sub.BackgroundTransparency = 1
                sub.Position = UDim2.fromOffset(0, 29)
                sub.Size = UDim2.new(1, 0, 0, 20)
                sub.Text = st.reasonKey and ((isEN() and REASON_EN or REASON_TR)[st.reasonKey]) or ""
                sub.Font = Enum.Font.GothamBold
                sub.TextSize = 13
                sub.TextColor3 = Color3.fromRGB(255, 120, 120)
                sub.TextStrokeTransparency = 0.15
                sub.TextStrokeColor3 = Color3.new(0, 0, 0)
                sub.Parent = root
            end

            st.gui, st.lbl, st.sub = root, lbl, sub
        end

        local function updateTagPositions()
            if not detOn then return end
            local cam = workspace.CurrentCamera
            if not cam then return end
            for p, st in pairs(det) do
                if st.holdUntil and os.clock() < st.holdUntil and st.gui and st.gui.Parent then
                    local char = p.Character
                    local head = char and (char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart"))
                    if head then
                        local worldPos = head.Position + Vector3.new(0, head.Size.Y * 0.5 + 1.65, 0)
                        local point, visible = cam:WorldToViewportPoint(worldPos)
                        local onScreen = visible and point.Z > 0
                            and point.X >= -100 and point.X <= cam.ViewportSize.X + 100
                            and point.Y >= -100 and point.Y <= cam.ViewportSize.Y + 100
                        st.gui.Visible = onScreen
                        if onScreen then
                            -- Etiketin alt kenarı başın biraz üstünde; ekran ölçekleme bunu kaydıramaz.
                            st.gui.Position = UDim2.fromOffset(point.X, point.Y - 10)
                        end
                    else
                        st.gui.Visible = false
                    end
                elseif st.gui then
                    st.gui.Visible = false
                end
            end
        end

        local function flag(p, st, key, now)
            st.reasonKey = key
            st.holdUntil = now + FLAG_HOLD
            showTag(st)
            if not st.active then
                st.active = true
                notify("Hile Tespit Edildi", p.Name .. "  •  " .. (isEN() and REASON_EN or REASON_TR)[key], 4)
            end
        end

        local function step(p, st, now, rp, op)
            local char = p.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if not hrp or not hum or hum.Health <= 0 then
                st.char, st.pos, st.t = nil, nil, nil
                return
            end
            if st.char ~= char then
                st.char, st.pos, st.t = char, nil, nil
                st.grace = now + 3
                st.c = newCounters()
            end

            local pos = hrp.Position
            local prevPos, prevT = st.pos, st.t
            st.pos, st.t = pos, now
            if not prevPos then return end
            local dt = now - prevT
            if dt <= 0 then return end
            local delta = pos - prevPos
            if delta.Magnitude > 120 then
                st.grace = now + 2
                st.c = newCounters()
                return
            end
            if now < (st.grace or 0) then return end

            local state
            pcall(function() state = hum:GetState() end)
            if hum.SeatPart ~= nil or hum.Sit
                or state == Enum.HumanoidStateType.Climbing
                or state == Enum.HumanoidStateType.Swimming then
                st.c = newCounters()
                return
            end

            local c = st.c or newCounters()
            st.c = c
            local hv = Vector3.new(delta.X, 0, delta.Z).Magnitude / dt
            local vy = delta.Y / dt
            local velocity = hrp.AssemblyLinearVelocity
            local horizontalVelocity = Vector3.new(velocity.X, 0, velocity.Z).Magnitude

            local hit = workspace:Raycast(pos, Vector3.new(0, -65, 0), rp)
            local height = hit and (pos.Y - hit.Position.Y - 3) or 65
            local floorMoving = false
            if hit and hit.Instance then
                pcall(function() floorMoving = hit.Instance.AssemblyLinearVelocity.Magnitude > 3 end)
            end

            -- Fly: yüksekteyken düşmeden ilerleme veya belirgin yükselme.
            local airborne = height > 10
            if airborne and (math.abs(vy) < 7 or vy > 22 or velocity.Y > 24) and not floorMoving then
                c.fly = c.fly + 1
            else
                c.fly = math.max(0, c.fly - 1)
            end

            -- Speed: hem pozisyon farkı hem de fizik hızı kullanılır.
            local speedLimit = math.max(hum.WalkSpeed, 16) * 1.9 + 10
            if math.max(hv, horizontalVelocity) > speedLimit and not floorMoving then
                c.speed = c.speed + 1
            else
                c.speed = math.max(0, c.speed - 1)
            end

            -- Noclip / harita altı.
            local inside = false
            if hv > 3 then
                local ok, parts = pcall(function()
                    return workspace:GetPartBoundsInRadius(pos, 0.65, op)
                end)
                if ok and parts then
                    for _, part in ipairs(parts) do
                        if part.CanCollide and part:IsA("Part") and part.Shape == Enum.PartType.Block
                            and part.Size.Magnitude > 4 then
                            local lp = part.CFrame:PointToObjectSpace(pos)
                            local half = part.Size / 2
                            if math.abs(lp.X) < half.X - 0.35
                                and math.abs(lp.Y) < half.Y - 0.35
                                and math.abs(lp.Z) < half.Z - 0.35 then
                                inside = true
                                break
                            end
                        end
                    end
                end
            end
            local under = false
            if not hit then
                under = workspace:Raycast(pos, Vector3.new(0, 18, 0), rp) ~= nil
            end
            if inside or under then c.noclip = c.noclip + 1
            else c.noclip = math.max(0, c.noclip - 1) end

            local av = 0
            pcall(function() av = hrp.AssemblyAngularVelocity.Magnitude end)
            if av > 32 then c.spin = c.spin + 1
            else c.spin = math.max(0, c.spin - 1) end

            for _, key in ipairs(ORDER) do
                if c[key] >= NEED[key] then
                    flag(p, st, key, now)
                    break
                end
            end
        end

        local function loop(myGen)
            local rp = RaycastParams.new()
            rp.FilterType = Enum.RaycastFilterType.Exclude
            rp.RespectCanCollide = true
            local op = OverlapParams.new()
            op.FilterType = Enum.RaycastFilterType.Exclude
            while alive and detOn and myGen == detGen do
                local now = os.clock()
                local chars = {}
                for _, pl in ipairs(Players:GetPlayers()) do
                    if pl.Character then chars[#chars + 1] = pl.Character end
                end
                op.FilterDescendantsInstances = chars
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer then
                        local st = det[p]
                        if not st then
                            st = {c = newCounters(), grace = 0}
                            det[p] = st
                        end
                        rp.FilterDescendantsInstances = p.Character and {p.Character} or {}
                        pcall(step, p, st, now, rp, op)
                        if st.holdUntil and now < st.holdUntil and p.Character then
                            pcall(showTag, st)
                        elseif st.active or st.gui then
                            st.active = false
                            st.holdUntil = nil
                            clearTag(st)
                        end
                    end
                end
                task.wait(SAMPLE)
            end
        end

        bind(Players.PlayerRemoving, function(p)
            local st = det[p]
            if st then clearTag(st) end
            det[p] = nil
        end)

        PX.detToggle = PX.toggle("🚨  Hileci Tespiti (Kırmızı HİLE Yazısı)", function(v)
            detOn = v
            detGen = detGen + 1
            if v then
                ensureLayer()
                if renderConn then renderConn:Disconnect() end
                renderConn = RunService.RenderStepped:Connect(updateTagPositions)
                task.spawn(loop, detGen)
                notify("Hileci Tespiti", "Aktif! Hile yapan oyuncunun üstünde kırmızı HİLE yazar.", 3)
            else
                if renderConn then renderConn:Disconnect() renderConn = nil end
                clearAll()
            end
        end)
        PX.onLock[#PX.onLock + 1] = function()
            detOn = false
            detGen = detGen + 1
            if renderConn then renderConn:Disconnect() renderConn = nil end
            clearAll()
        end
        -- Script her açıldığında (premium doğrulanınca) Hileci Tespiti kendiliğinden başlar;
        -- aç-kapa yapmak gerekmez. Yalnızca ilk doğrulamada çalışır: sonradan elle kapatırsan
        -- 20 sn'lik premium kontrolü onu tekrar açmaz.
        PX.onUnlock = PX.onUnlock or {}
        PX.onUnlock[#PX.onUnlock + 1] = function()
            if PX.detAutoDone then return end
            PX.detAutoDone = true
            if not detOn and PX.detToggle then PX.detToggle.Set(true) end
        end
    end

    createSection(PremiumPage, "👑  PREMİUM ARAÇLAR")

    -- Anti-AFK: Farm'daki korumayla aynı güvenli bağlantı yönetimi.
    -- Yalnızca Roblox'un standart Idled/boşta kalma sinyalini ele alır.
    do
        local afkConn = nil
        local function setManualAntiAFK(enabled)
            if enabled then
                if afkConn then return true end
                local ok, conn = pcall(function()
                    return LocalPlayer.Idled:Connect(function()
                        pcall(function()
                            local vu = game:GetService("VirtualUser")
                            vu:CaptureController()
                            vu:ClickButton2(Vector2.new())
                        end)
                    end)
                end)
                if ok and conn then
                    afkConn = conn
                    conns[#conns + 1] = conn
                    return true
                end
                afkConn = nil
                return false
            end

            if afkConn then
                pcall(function() afkConn:Disconnect() end)
                afkConn = nil
            end
            return true
        end

        PX.toggle("🛡️  Anti-AFK (Atılmayı Engelle)", function(v)
            local ok = setManualAntiAFK(v)
            if v then
                if ok then
                    notify("Anti-AFK", "Etkin. Standart boşta kalma sinyali izleniyor.", 2)
                else
                    notify("Anti-AFK", "Etkinleştirilemedi; executor desteğini kontrol et.", 3)
                end
            end
        end)
    end

    PX.button("🔄  Sunucuya Yeniden Gir (Rejoin)", function()
        notify("Rejoin", "Aynı sunucuya yeniden bağlanılıyor...", 3)
        pcall(function()
            local ts = game:GetService("TeleportService")
            if #Players:GetPlayers() <= 1 then
                ts:Teleport(game.PlaceId, LocalPlayer)
            else
                ts:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
            end
        end)
    end)

    PX.button("📋  Sunucu ID'sini Kopyala (JobId)", function()
        if PX.copy(game.JobId) then
            notify("Kopyalandı", "Sunucu ID panoya kopyalandı.", 2)
        else
            notify("Kopyalanamadı", "Executor panoya yazmayı desteklemiyor.", 3)
        end
    end)

    PX.button("🎮  Oyun ID'sini Kopyala (PlaceId)", function()
        if PX.copy(tostring(game.PlaceId)) then
            notify("Kopyalandı", "Oyun ID panoya kopyalandı.", 2)
        else
            notify("Kopyalanamadı", "Executor panoya yazmayı desteklemiyor.", 3)
        end
    end)

PX.secHolders.aura = createSection(PremiumPage, "✨  AURA EFEKTLERİ")
;(function()
    local WHITE, BLACK = Color3.new(1, 1, 1), Color3.new(0, 0, 0)
    local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end
    local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
    local FIRE = "rbxasset://textures/particles/fire_main.dds"
    local SPARK = "rbxasset://textures/particles/sparkles_main.dds"

    local function cs(...)
        local cols = {...}
        if #cols == 1 then return ColorSequence.new(cols[1]) end
        local k = {}
        for i, c in ipairs(cols) do k[i] = ColorSequenceKeypoint.new((i - 1) / (#cols - 1), c) end
        return ColorSequence.new(k)
    end

    ---------------------------------------------------------
    -- AURA TANIMLARI
    --  em     = parçacık efektleri     bolts = şimşekler
    --  wings  = kanatlar               orbit = etrafında dönen parçalar
    --  trail  = uzuvlarda iz           rgb   = renk döngüsü
    ---------------------------------------------------------
    local AURAS = {
        {id = "simsek", name = "⚡  Şimşek Aurası (Siyah-Beyaz)",
            em = {
                {tex = SMOKE, color = cs(BLACK, rgb(45, 45, 50)), rate = 16, s0 = 3, s1 = 5, light = 0, t0 = 0.3, l0 = 1, l1 = 1.6, v0 = 1, v1 = 2},
                {tex = SPARK, color = cs(WHITE), rate = 28, s0 = 0.6, s1 = 0, light = 1, v0 = 3, v1 = 6},
            },
            bolts = {n = 6, cols = {WHITE, BLACK}, r = 3.6}},
        {id = "tanri", name = "🪽  Tanrı Aurası (Kanat + Şimşek)",
            em = {{tex = SPARK, color = cs(WHITE, rgb(200, 215, 255)), rate = 30, s0 = 0.7, s1 = 0, light = 1, v0 = 2, v1 = 5}},
            wings = {c1 = WHITE, c2 = rgb(170, 195, 255), n = 7},
            bolts = {n = 5, cols = {WHITE, rgb(150, 190, 255)}, r = 3.4},
            orbit = {n = 8, cols = {WHITE, BLACK}, r = 3.2, speed = 2, size = 0.35}},
        {id = "melek", name = "😇  Melek Kanatları",
            em = {{tex = SPARK, color = cs(WHITE, rgb(255, 240, 190)), rate = 18, s0 = 0.6, s1 = 0, light = 1, v0 = 1, v1 = 3}},
            wings = {c1 = WHITE, c2 = rgb(255, 235, 170), n = 8}},
        {id = "karamelek", name = "🦇  Kara Kanatlar",
            em = {
                {tex = SMOKE, color = cs(BLACK, rgb(30, 10, 14)), rate = 14, s0 = 3, s1 = 5, light = 0, t0 = 0.35, l0 = 1, l1 = 1.5, v0 = 1, v1 = 2},
                {tex = SPARK, color = cs(rgb(255, 40, 60)), rate = 14, s0 = 0.5, s1 = 0, light = 1, v0 = 2, v1 = 4},
            },
            wings = {c1 = rgb(14, 14, 18), c2 = rgb(90, 8, 20), n = 7, neon = false}},
        {id = "siyahbeyazalev", name = "🖤  Siyah-Beyaz Alev",
            em = {
                {tex = FIRE, color = cs(BLACK, rgb(30, 30, 30)), rate = 30, s0 = 3.5, s1 = 1, light = 0, t0 = 0.1, l0 = 0.8, l1 = 1.3, v0 = 2, v1 = 4, acc = Vector3.new(0, 9, 0)},
                {tex = FIRE, color = cs(WHITE, rgb(210, 210, 210)), rate = 22, s0 = 2.5, s1 = 0.5, light = 1, t0 = 0.2, l0 = 0.6, l1 = 1, v0 = 2, v1 = 4, acc = Vector3.new(0, 9, 0)},
            },
            trail = {c1 = WHITE, c2 = BLACK}},
        {id = "girdap", name = "🌀  Siyah-Beyaz Girdap",
            em = {{tex = SMOKE, color = cs(BLACK, rgb(70, 70, 75)), rate = 12, s0 = 2.5, s1 = 4, light = 0, t0 = 0.4, l0 = 1, l1 = 1.5, v0 = 1, v1 = 2}},
            orbit = {n = 14, cols = {WHITE, BLACK}, r = 3.4, speed = 3.2, size = 0.4}},
        {id = "saiyan", name = "💛  Süper Saiyan",
            em = {
                {tex = FIRE, color = cs(rgb(255, 230, 80), rgb(255, 150, 0)), rate = 40, s0 = 3.5, s1 = 0.8, light = 1, t0 = 0.15, l0 = 0.7, l1 = 1.2, v0 = 3, v1 = 6, acc = Vector3.new(0, 12, 0)},
                {tex = SPARK, color = cs(rgb(255, 255, 160)), rate = 25, s0 = 0.6, s1 = 0, light = 1, v0 = 4, v1 = 8},
            },
            bolts = {n = 6, cols = {rgb(255, 235, 90), rgb(255, 255, 200)}, r = 3.6}},
        {id = "mavi", name = "💙  Mavi Ruh Aurası",
            em = {
                {tex = FIRE, color = cs(rgb(120, 220, 255), rgb(20, 90, 255)), rate = 36, s0 = 3.2, s1 = 0.8, light = 1, t0 = 0.15, l0 = 0.7, l1 = 1.2, v0 = 3, v1 = 5, acc = Vector3.new(0, 11, 0)},
                {tex = SPARK, color = cs(rgb(190, 240, 255)), rate = 20, s0 = 0.6, s1 = 0, light = 1, v0 = 3, v1 = 6},
            },
            bolts = {n = 5, cols = {rgb(120, 220, 255), WHITE}, r = 3.4}},
        {id = "kirmizi", name = "🔥  Kırmızı Alev Aurası",
            em = {
                {tex = FIRE, color = cs(rgb(255, 210, 60), rgb(255, 40, 20)), rate = 42, s0 = 3.4, s1 = 0.6, light = 1, t0 = 0.1, l0 = 0.7, l1 = 1.2, v0 = 3, v1 = 6, acc = Vector3.new(0, 12, 0)},
                {tex = SMOKE, color = cs(rgb(40, 10, 10)), rate = 10, s0 = 3, s1 = 5, light = 0, t0 = 0.5, l0 = 1, l1 = 1.6, v0 = 2, v1 = 4},
            }},
        {id = "cehennem", name = "😈  Cehennem Kanatları",
            em = {{tex = FIRE, color = cs(rgb(255, 200, 40), rgb(255, 50, 10)), rate = 26, s0 = 2.6, s1 = 0.5, light = 1, t0 = 0.15, l0 = 0.6, l1 = 1, v0 = 2, v1 = 4, acc = Vector3.new(0, 10, 0)}},
            wings = {c1 = rgb(255, 60, 20), c2 = rgb(255, 190, 40), n = 7}},
        {id = "galaksi", name = "🌌  Galaksi Aurası",
            em = {{tex = SPARK, color = cs(rgb(150, 90, 255), rgb(60, 120, 255), rgb(255, 120, 230)), rate = 40, s0 = 0.9, s1 = 0, light = 1, v0 = 1, v1 = 4, acc = Vector3.new(0, 2, 0)}},
            orbit = {n = 10, cols = {rgb(180, 120, 255), rgb(90, 160, 255), rgb(255, 150, 240)}, r = 3.3, speed = 1.6, size = 0.3}},
        {id = "buz", name = "❄️  Buz Aurası",
            em = {
                {tex = SPARK, color = cs(WHITE, rgb(160, 225, 255)), rate = 34, s0 = 0.7, s1 = 0, light = 1, v0 = 1, v1 = 3, acc = Vector3.new(0, -2, 0)},
                {tex = SMOKE, color = cs(rgb(200, 240, 255)), rate = 10, s0 = 3, s1 = 5, light = 0.4, t0 = 0.6, l0 = 1, l1 = 1.6, v0 = 1, v1 = 2},
            },
            trail = {c1 = rgb(180, 235, 255), c2 = WHITE}},
        {id = "golge", name = "☠️  Ölüm Gölgesi",
            em = {
                {tex = SMOKE, color = cs(BLACK, rgb(30, 0, 50)), rate = 24, s0 = 3.5, s1 = 6, light = 0, t0 = 0.2, l0 = 1.2, l1 = 1.8, v0 = 1, v1 = 3},
                {tex = SPARK, color = cs(rgb(170, 60, 255)), rate = 18, s0 = 0.6, s1 = 0, light = 1, v0 = 2, v1 = 5},
            },
            trail = {c1 = rgb(150, 40, 255), c2 = BLACK}},
        {id = "rgb", name = "🌈  RGB Aura",
            em = {
                {tex = FIRE, color = cs(WHITE), rate = 34, s0 = 3, s1 = 0.6, light = 1, t0 = 0.15, l0 = 0.7, l1 = 1.1, v0 = 3, v1 = 5, acc = Vector3.new(0, 10, 0)},
                {tex = SPARK, color = cs(WHITE), rate = 24, s0 = 0.6, s1 = 0, light = 1, v0 = 3, v1 = 6},
            },
            bolts = {n = 5, cols = {WHITE}, r = 3.4}, orbit = {n = 8, cols = {WHITE}, r = 3.2, speed = 2.4, size = 0.35}, rgb = true},
        {id = "golgehiz", name = "💨  Gölge Hız (Siyah-Beyaz İz)",
            em = {{tex = SMOKE, color = cs(BLACK, rgb(60, 60, 60)), rate = 14, s0 = 2.5, s1 = 4, light = 0, t0 = 0.4, l0 = 0.8, l1 = 1.2, v0 = 1, v1 = 2}},
            trail = {c1 = WHITE, c2 = BLACK}},
        {id = "sakura", name = "🌸  Sakura Yaprakları",
            em = {{tex = SPARK, color = cs(rgb(255, 170, 205), rgb(255, 225, 235)), rate = 22, s0 = 1.1, s1 = 0.6, light = 0.6, t0 = 0.1, l0 = 2, l1 = 3, v0 = 0.5, v1 = 2, acc = Vector3.new(0, -1.5, 0), spread = 180}}},
        {id = "zehir", name = "☣️  Zehir Aurası",
            em = {
                {tex = SMOKE, color = cs(rgb(70, 255, 90), rgb(20, 90, 30)), rate = 18, s0 = 3, s1 = 5, light = 0.6, t0 = 0.3, l0 = 1, l1 = 1.6, v0 = 1, v1 = 3},
                {tex = SPARK, color = cs(rgb(160, 255, 120)), rate = 16, s0 = 0.6, s1 = 0, light = 1, v0 = 2, v1 = 5},
            }},
        {id = "halka", name = "🔱  Işık Halkaları",
            em = {{tex = SPARK, color = cs(rgb(255, 230, 140), WHITE), rate = 20, s0 = 0.7, s1 = 0, light = 1, v0 = 1, v1 = 3}},
            orbit = {n = 18, cols = {rgb(255, 225, 120), WHITE}, r = 3.6, speed = 1.3, size = 0.28, rings = true}},
    }
    local BY_ID = {}
    for _, a in ipairs(AURAS) do BY_ID[a.id] = a end

    ---------------------------------------------------------
    -- Yardımcılar
    ---------------------------------------------------------
    local function emitter(parent, o)
        local e = Instance.new("ParticleEmitter")
        local function set(k, v) pcall(function() e[k] = v end) end
        set("Texture", o.tex or SPARK)
        set("Color", o.color or cs(WHITE))
        set("LightEmission", o.light or 0.5)
        set("LightInfluence", 0)
        set("Size", NumberSequence.new({NumberSequenceKeypoint.new(0, o.s0 or 1), NumberSequenceKeypoint.new(1, o.s1 or 0)}))
        set("Transparency", NumberSequence.new({
            NumberSequenceKeypoint.new(0, o.t0 or 0.2),
            NumberSequenceKeypoint.new(0.65, o.tm or 0.5),
            NumberSequenceKeypoint.new(1, 1),
        }))
        set("Lifetime", NumberRange.new(o.l0 or 0.8, o.l1 or 1.4))
        set("Rate", o.rate or 20)
        set("Speed", NumberRange.new(o.v0 or 1, o.v1 or 3))
        local sp = o.spread or 25
        set("SpreadAngle", Vector2.new(sp, sp))
        set("Acceleration", o.acc or Vector3.new(0, 5, 0))
        set("Rotation", NumberRange.new(0, 360))
        set("RotSpeed", NumberRange.new(-60, 60))
        set("EmissionDirection", Enum.NormalId.Top)
        set("LockedToPart", false)
        e.Parent = parent
        return e
    end

    local function isDark(c)
        return (c.R + c.G + c.B) < 0.35
    end

    local current = nil   -- {conn, folder, extra}
    local function clearAura()
        if not current then return end
        if current.conn then pcall(function() current.conn:Disconnect() end) end
        if current.folder then pcall(function() current.folder:Destroy() end) end
        for _, o in ipairs(current.extra or {}) do pcall(function() o:Destroy() end) end
        current = nil
    end

    local function makePart(folder, size, color, neon, transp)
        local p = Instance.new("Part")
        p.Size = size
        p.Color = color
        p.Material = neon and Enum.Material.Neon or Enum.Material.SmoothPlastic
        p.Transparency = transp or 0
        p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
        p.CastShadow = false
        p.Massless = true
        p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
        p.Parent = folder
        return p
    end

    ---------------------------------------------------------
    -- Uygulama
    ---------------------------------------------------------
    local function applyAura(def, ch)
        clearAura()
        if not def or not ch or not ch.Parent then return end
        local hrp = ch:FindFirstChild("HumanoidRootPart") or ch:WaitForChild("HumanoidRootPart", 5)
        if not hrp then return end

        local folder = Instance.new("Folder")
        folder.Name = "EZRAGOX_Aura"
        folder.Parent = ch
        local rec = {folder = folder, extra = {}}
        current = rec

        -- Vücudu saran görünmez gövde (parçacıklar buradan çıkar)
        local anchor = makePart(folder, Vector3.new(3, 5, 3), WHITE, false, 1)
        anchor.CFrame = hrp.CFrame
        local aw = Instance.new("WeldConstraint")
        aw.Part0, aw.Part1 = hrp, anchor
        aw.Parent = anchor

        local emitters = {}
        for _, spec in ipairs(def.em or {}) do
            emitters[#emitters + 1] = emitter(anchor, spec)
        end

        -- Şimşekler: her biri 4 parçalı zikzaklı ışın zinciri
        local bolts = {}
        if def.bolts then
            local center = Instance.new("Attachment")
            center.Position = Vector3.new(0, 0, 0)
            center.Parent = anchor
            for i = 1, def.bolts.n do
                local col = def.bolts.cols[(i - 1) % #def.bolts.cols + 1]
                local pts = {center}
                for k = 1, 4 do
                    local a = Instance.new("Attachment")
                    a.Parent = anchor
                    pts[#pts + 1] = a
                end
                local beams = {}
                for k = 1, 4 do
                    local b = Instance.new("Beam")
                    b.Attachment0, b.Attachment1 = pts[k], pts[k + 1]
                    b.Color = ColorSequence.new(col)
                    b.LightEmission = isDark(col) and 0 or 1
                    b.LightInfluence = 0
                    b.Width0, b.Width1 = 0.2 - k * 0.025, 0.2 - (k + 1) * 0.025
                    b.Segments = 1
                    b.FaceCamera = true
                    b.Transparency = NumberSequence.new(0.05)
                    b.Parent = anchor
                    beams[k] = b
                end
                bolts[i] = {pts = pts, beams = beams, col = col}
            end
        end

        -- Kanatlar: 3 katman tüy, yelpaze şeklinde (gerçek kanat görünümü)
        local feathers = {}
        if def.wings then
            local torso = ch:FindFirstChild("UpperTorso") or ch:FindFirstChild("Torso")
            if torso then
                local neon = def.wings.neon ~= false
                -- üstte kısa örtü tüyleri, altta uzun uçuş tüyleri (arkadan bakınca en üstteki katman kısa olanlar)
                local ROWS = {
                    {n = 9, lenF = 1.00, zOff = 0.00, w = 0.24, transp = 0.08},
                    {n = 9, lenF = 0.62, zOff = 0.07, w = 0.32, transp = 0.05},
                    {n = 7, lenF = 0.34, zOff = 0.14, w = 0.46, transp = 0.03},
                }
                for side = -1, 1, 2 do
                    for ri, row in ipairs(ROWS) do
                        for i = 1, row.n do
                            local u = (i - 1) / (row.n - 1)
                            -- kol çizgisi: gövdeden yukarı-dışarı kavisli; tüyler buradan aşağı-dışarı yelpaze olur
                            local WS = 0.72   -- kanat boyutu (küçültme çarpanı)
                            local ax = (0.15 + 2.0 * u) * WS
                            local ay = (0.4 + 2.3 * u + math.sin(u * math.pi) * 0.35) * WS
                            local phi = math.rad(-72 + 92 * u)
                            local len = (2.0 + 3.6 * u ^ 0.85) * row.lenF * WS
                            local dir = Vector3.new(side * math.cos(phi), math.sin(phi), 0)
                            local origin = Vector3.new(side * ax, ay, row.zOff)
                            local yv = Vector3.new(0, 0, 1)
                            local xv = yv:Cross(dir)
                            local fcf = CFrame.fromMatrix(origin + dir * (len / 2), xv, yv, dir)
                            local width = math.max(0.32, len * row.w)
                            local col = def.wings.c2:Lerp(def.wings.c1, u)
                            if neon then col = col:Lerp(WHITE, (ri - 1) * 0.12) end
                            local part = makePart(folder, Vector3.new(width, 0.05, len), col, neon, row.transp)
                            local mesh = Instance.new("SpecialMesh")
                            mesh.MeshType = Enum.MeshType.Sphere
                            mesh.Parent = part
                            local weld = Instance.new("Weld")
                            weld.Part0, weld.Part1 = torso, part
                            weld.Parent = part
                            feathers[#feathers + 1] = {weld = weld, side = side, u = u, fcf = fcf}
                        end
                    end
                end
            end
        end

        -- Etrafında dönen parçalar
        local orbit = {}
        if def.orbit then
            for i = 1, def.orbit.n do
                local col = def.orbit.cols[(i - 1) % #def.orbit.cols + 1]
                local p = makePart(folder, Vector3.new(def.orbit.size, def.orbit.size, def.orbit.size), col, not isDark(col), 0.1)
                p.Anchored, p.Massless = true, false
                p.Shape = Enum.PartType.Ball
                orbit[i] = {part = p, i = i}
            end
        end

        -- Uzuvlarda iz
        if def.trail then
            local names = {"RightHand", "LeftHand", "RightFoot", "LeftFoot", "Right Arm", "Left Arm", "Right Leg", "Left Leg"}
            for _, nme in ipairs(names) do
                local limb = ch:FindFirstChild(nme)
                if limb and limb:IsA("BasePart") then
                    local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
                    a0.Position, a1.Position = Vector3.new(0, 0.5, 0), Vector3.new(0, -0.5, 0)
                    a0.Parent, a1.Parent = limb, limb
                    local tr = Instance.new("Trail")
                    tr.Attachment0, tr.Attachment1 = a0, a1
                    tr.Color = cs(def.trail.c1, def.trail.c2)
                    tr.Lifetime = 0.5
                    tr.LightEmission = isDark(def.trail.c2) and 0.4 or 1
                    tr.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1)})
                    tr.Parent = limb
                    rec.extra[#rec.extra + 1] = a0
                    rec.extra[#rec.extra + 1] = a1
                    rec.extra[#rec.extra + 1] = tr
                end
            end
        end

        local t0, acc = os.clock(), 0
        local radius = def.bolts and def.bolts.r or 3.5
        rec.conn = RunService.Heartbeat:Connect(function(dt)
            if not alive or not hrp.Parent then return end
            local t = os.clock() - t0
            local hue = (t * 0.25) % 1

            -- RGB döngüsü
            if def.rgb then
                local c1, c2 = Color3.fromHSV(hue, 1, 1), Color3.fromHSV((hue + 0.3) % 1, 1, 1)
                for _, e in ipairs(emitters) do e.Color = ColorSequence.new(c1, c2) end
                for _, b in ipairs(bolts) do
                    for _, bm in ipairs(b.beams) do bm.Color = ColorSequence.new(c1) end
                end
                for _, o in ipairs(orbit) do o.part.Color = Color3.fromHSV((hue + o.i * 0.08) % 1, 1, 1) end
            end

            -- Kanat çırpma
            for _, fe in ipairs(feathers) do
                local flap = math.rad(8) * math.sin(t * 2.2 - fe.u * 1.1) + math.rad(5)
                fe.weld.C0 = CFrame.new(0, 0.35, 0.55)
                    * CFrame.Angles(0, -fe.side * math.rad(18), 0)
                    * CFrame.Angles(0, 0, fe.side * flap)
                    * fe.fcf
            end

            -- Dönen parçalar
            if #orbit > 0 then
                local base = hrp.Position
                local o = def.orbit
                for _, it in ipairs(orbit) do
                    local ang = t * o.speed + it.i * (math.pi * 2 / o.n)
                    local h
                    if o.rings then
                        h = ((it.i % 2 == 0) and 1.6 or -1.6) + math.sin(t * 2 + it.i) * 0.15
                    else
                        h = math.sin(t * 2 + it.i) * 1.4
                    end
                    it.part.CFrame = CFrame.new(base + Vector3.new(math.cos(ang) * o.r, h, math.sin(ang) * o.r))
                end
            end

            -- Şimşekleri yeniden çiz (~14 kez/sn)
            acc = acc + dt
            if acc >= 0.07 and #bolts > 0 then
                acc = 0
                for _, b in ipairs(bolts) do
                    local visible = math.random() < 0.75
                    local dir = Vector3.new(math.random() * 2 - 1, math.random() * 2 - 1, math.random() * 2 - 1)
                    if dir.Magnitude < 0.1 then dir = Vector3.yAxis end
                    dir = dir.Unit
                    for k = 2, 5 do
                        local jitter = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 1.1
                        b.pts[k].Position = dir * radius * ((k - 1) / 4) + jitter
                    end
                    for _, bm in ipairs(b.beams) do bm.Enabled = visible end
                end
            end
        end)
    end

    ---------------------------------------------------------
    -- Seçim + kalıcılık (ölünce / yeniden doğunca / kayıtlı ayar)
    ---------------------------------------------------------
    local selectedDef = Settings.Aura and BY_ID[Settings.Aura] or nil
    local labels = {}

    local function markSelected()
        for id, lbl in pairs(labels) do
            local def = BY_ID[id]
            setText(lbl, def.name .. ((selectedDef and selectedDef.id == id) and "  ✅" or ""))
        end
    end

    local function selectAura(def)
        if def and not PX.unlocked then
            notify("Premium Gerekli", "Aura sadece premium kullanıcılar içindir.", 3)
            return
        end
        selectedDef = def
        Settings.Aura = def and def.id or nil
        saveConfig()
        markSelected()
        if def then
            task.spawn(function() applyAura(def, LocalPlayer.Character) end)
            notify("Aura", def.name .. " aktif! (Ölsen de, resetlesen de üstünde kalır)", 3)
        else
            clearAura()
            notify("Aura", "Aura kapatıldı.", 2)
        end
    end

    bind(LocalPlayer.CharacterAdded, function(ch)
        if not selectedDef or not PX.unlocked then return end
        task.spawn(function()
            ch:WaitForChild("HumanoidRootPart", 8)
            task.wait(0.25)
            if selectedDef and LocalPlayer.Character == ch then applyAura(selectedDef, ch) end
        end)
    end)

    -- Script açılır açılmaz kayıtlı aura varsa uygula
    if selectedDef then
        task.spawn(function()
            local t0 = os.clock()
            while alive and not PX.unlocked and os.clock() - t0 < 90 do task.wait(1) end
            if not (alive and PX.unlocked) then return end
            task.wait(1)
            if selectedDef and LocalPlayer.Character then applyAura(selectedDef, LocalPlayer.Character) end
        end)
    end

    ---------------------------------------------------------
    -- Arayüz: açılır liste
    ---------------------------------------------------------
    local header, headerSt = baseRow(PremiumPage, "TextButton", 42)
    rowLabel(header, "✨  Aura Seç  (" .. #AURAS .. " adet)")
    local arrow = new("TextLabel", {
        Size = UDim2.new(0, 30, 1, 0), Position = UDim2.new(1, -36, 0, 0), BackgroundTransparency = 1,
        Text = "▾", Font = Enum.Font.GothamBold, TextSize = 18, TextColor3 = Color3.fromRGB(120, 134, 170), ZIndex = 4,
    }, header)
    hoverFx(header, headerSt)

    local PANEL_H = 320
    local content = new("ScrollingFrame", {
        LayoutOrder = nextOrder(PremiumPage),
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundTransparency = 1, BorderSizePixel = 0, ClipsDescendants = true,
        ScrollBarThickness = 3, ScrollBarImageColor3 = Color3.fromRGB(255, 42, 58),
        CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ZIndex = 3,
    }, PremiumPage)
    new("UIPadding", {PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4)}, content)
    new("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 3)}, content)

    for _, def in ipairs(AURAS) do
        local btn = createButton(content, def.name, function() selectAura(def) end)
        for _, c in ipairs(btn:GetChildren()) do
            if c:IsA("TextLabel") and c.Text ~= "›" then labels[def.id] = c break end
        end
    end
    createButton(content, "♻️  Aurayı Kapat", function() selectAura(nil) end)
    markSelected()

    PX.onLock[#PX.onLock + 1] = function() pcall(clearAura) end

    local open = false
    bind(header.MouseButton1Click, function()
        playClickSound()
        open = not open
        setText(arrow, open and "▴" or "▾")
        tween(content, 0.22, {Size = UDim2.new(1, 0, 0, open and PANEL_H or 0)})
    end)
end)()


    -- Gökkuşağı aura
    do
        local rainbowOn, hl = false, nil
        bind(RunService.Heartbeat, function()
            if not rainbowOn then return end
            local char = LocalPlayer.Character
            if not char then return end
            if not hl or hl.Parent ~= char then
                if hl then hl:Destroy() end
                hl = new("Highlight", {
                    Name = "EZRAGOX_Rainbow", FillTransparency = 0.35, OutlineTransparency = 0,
                    OutlineColor = Color3.new(1, 1, 1),
                }, char)
            end
            hl.FillColor = Color3.fromHSV((os.clock() * 0.35) % 1, 1, 1)
        end)
        PX.toggle("🌈  Gökkuşağı Aura", function(v)
            rainbowOn = v
            if not v and hl then
                hl:Destroy()
                hl = nil
            elseif v then
                notify("Gökkuşağı Aura", "Karakterin renk değiştiriyor!", 2)
            end
        end)
    end


    ---------------------------------------------------------
    -- 👗 GÖRÜNÜM: en öndeki ana başlık; altında Aura, Headless & Korblox,
    -- Kıyafet (giysi kopyalama), Animasyon ve Sahte Rütbe kendi başlıklarıyla sıralanır
    ---------------------------------------------------------
    do
        local mh = createSection(PremiumPage, "👗  GÖRÜNÜM")
        PX.secHolders.main = mh
        pcall(function()
            for _, c in ipairs(mh:GetChildren()) do
                if c:IsA("Frame") and c:FindFirstChildOfClass("UICorner") then
                    c.BackgroundColor3 = Color3.fromRGB(92, 14, 30)
                    c.BackgroundTransparency = 0.02
                    local st = c:FindFirstChildOfClass("UIStroke")
                    if st then
                        st.Color = Color3.fromRGB(255, 60, 78)
                        st.Transparency = 0.1
                        st.Thickness = 1.5
                    end
                end
            end
        end)

        local function isHead(c)
            if not c:IsA("Frame") or c:FindFirstChildOfClass("UICorner") then return false end
            local l = c:FindFirstChildOfClass("TextLabel")
            return l ~= nil and l.Font == Enum.Font.GothamBlack and l.TextSize == 11
        end
        local kids = {}
        for _, c in ipairs(PremiumPage:GetChildren()) do
            if c:IsA("GuiObject") then kids[#kids + 1] = c end
        end
        table.sort(kids, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
        local segs, cur = {}, nil
        for _, c in ipairs(kids) do
            if isHead(c) or not cur then
                cur = {head = c, items = {}}
                segs[#segs + 1] = cur
            end
            cur.items[#cur.items + 1] = c
        end
        local byHead = {}
        for _, s in ipairs(segs) do byHead[s.head] = s end
        local placed, final = {}, {}
        for _, key in ipairs({"lock", "status", "main", "aura", "headless", "outfit", "anim", "tag"}) do
            local h = PX.secHolders[key]
            local s = h and byHead[h]
            if s and not placed[s] then
                placed[s] = true
                final[#final + 1] = s
            end
        end
        for _, s in ipairs(segs) do
            if not placed[s] then final[#final + 1] = s end
        end
        local n = 0
        for _, s in ipairs(final) do
            for _, c in ipairs(s.items) do
                n = n + 1
                c.LayoutOrder = n
            end
        end
    end

    collectNew(PremiumPage, before, PX.premiumRows)
    -- açılır menü gövdeleri premium kilidiyle otomatik açılmasın (başlığa basınca açılır)
    for _, body in ipairs(PX.collapsibles) do
        for i = #PX.premiumRows, 1, -1 do
            if PX.premiumRows[i] == body then table.remove(PX.premiumRows, i) end
        end
    end
end

function PX.setPremium(v, viaAdmin)
    PX.unlocked = v and true or false
    Settings.PremiumActive = PX.unlocked   -- diğer sekmelerdeki premium özellikler bunu okur
    for _, o in ipairs(Settings.PremiumGated or {}) do
        if not PX.unlocked then
            pcall(o.Set, false, false, true)   -- kapat (kayıtlı durum silinmez)
        elseif Settings.ToggleStates[o.Key] == true then
            -- sessiz: bu, 20 sn'de bir yapılan otomatik premium kontrolünden gelebilir,
            -- zaten açık olan özellik için tekrar tekrar bildirim göstermesin
            pcall(o.Set, true, true)
        end
    end
    for _, r in ipairs(PX.lockRows) do r.Visible = not PX.unlocked end
    for _, r in ipairs(PX.premiumRows) do r.Visible = PX.unlocked end
    if not PX.unlocked then
        for _, o in ipairs(PX.toggles) do pcall(o.Set, false, true, true) end
        for _, f in ipairs(PX.onLock) do pcall(f) end
    else
        for _, o in ipairs(PX.toggles) do
            -- sessiz: aynı sebep, periyodik premium doğrulaması zaten açık özelliği tekrar bildirmesin
            if Settings.ToggleStates[o.Key] == true then pcall(o.Set, true, true) end
        end
        for _, f in ipairs(PX.onUnlock or {}) do pcall(f) end
    end
    if PX.statusBody then
        if viaAdmin then
            setText(PX.statusBody, "Yönetici erişimi ile açık.")
        else
            setText(PX.statusBody, "Hesap: " .. LocalPlayer.Name .. "  •  premium tanımlı.")
        end
    end
end

function PX.dbRequest(method, path, body, auth)
    local req = request or http_request or (syn and syn.request)
    if not req or KEY_DB_URL == "" then return nil end
    local base = KEY_DB_URL:gsub("/+$", "")
    local url = base .. "/" .. path .. ".json"
    if auth and auth ~= "" then url = url .. "?auth=" .. auth end
    local ok, res = pcall(req, {
        Url = url, Method = method, Headers = {["Content-Type"] = "application/json"},
        Body = (body ~= nil) and HttpService:JSONEncode(body) or nil,
    })
    if not ok or type(res) ~= "table" then return nil end
    return res
end

function PX.isListed()
    local lname = LocalPlayer.Name:lower()
    for _, n in ipairs(PREMIUM_NAMES) do
        if tostring(n):lower() == lname then return true end
    end
    return false
end

-- Bu hesapta premium var mı? (koddaki liste + veritabanı)
function PX.checkPremium(silent)
    if PX.admin then return end
    local has, offline = PX.isListed(), false
    if not has and KEY_DB_URL ~= "" then
        local res = PX.dbRequest("GET", "ezragox_premium/" .. LocalPlayer.UserId)
        if res and res.StatusCode == 200 then
            has = (res.Body ~= nil and res.Body ~= "null" and res.Body ~= "")
        else
            offline = true
        end
    end
    if has then
        local was = PX.unlocked
        PX.setPremium(true, false)
        if not silent or not was then notify("Premium Aktif 👑", "Hesabın için premium tanımlı, hoş geldin!", 4) end
    elseif not offline then
        PX.setPremium(false)
        if not silent then notify("Premium Yok", LocalPlayer.Name .. " hesabında premium tanımlı değil.", 4) end
    elseif not silent then
        notify("Bağlantı Hatası", "Premium sunucusuna ulaşılamadı. Tekrar dene.", 4)
    end
end

PX.setPremium(false)
task.spawn(function() PX.checkPremium(true) end)
-- Premium durumunu 20 saniyede bir yeniden kontrol et (kaldırılınca kısa sürede kapanır)
task.spawn(function()
    while alive do
        task.wait(20)
        if KEY_DB_URL ~= "" then pcall(PX.checkPremium, true) end
    end
end)

---------------------------------------------------------
-- AKTİF KULLANICI SAYACI (ana sayfadaki kart)
-- Her kullanıcı rastgele ve ANONİM bir oturum kimliğiyle 60 sn'de bir "buradayım" der
-- (Roblox adı / ID gönderilmez). Son 150 sn içinde görünenler "aktif" sayılır.
-- Çıkışta kendi kaydını siler. Ağ işlemleri ayrı iş parçacığında çalışır, oyunu yavaşlatmaz.
---------------------------------------------------------
task.spawn(function()
    local label = Settings.ActiveUsersLabel
    if not label then return end
    local sid = string.gsub(HttpService:GenerateGUID(false), "[^%w]", "")
    local mine = "ezragox_active/" .. sid

    local function readCount()
        local res = PX.dbRequest("GET", "ezragox_active")
        if not (res and res.StatusCode == 200) then return nil end
        if res.Body == nil or res.Body == "null" or res.Body == "" then return 0 end
        local ok, data = pcall(function() return HttpService:JSONDecode(res.Body) end)
        if not ok then return nil end
        if type(data) ~= "table" then return 0 end
        local now, n, cleaned = os.time(), 0, 0
        for k, t in pairs(data) do
            if type(t) == "number" then
                local age = now - t
                if age <= 150 then
                    n = n + 1
                elseif age > 900 and cleaned < 5 then
                    cleaned = cleaned + 1 -- eski kayıtları (kapanmayanlar) döngü başına en fazla 5 tane sil
                    PX.dbRequest("DELETE", "ezragox_active/" .. tostring(k))
                end
            end
        end
        return n
    end

    while alive do
        local put = PX.dbRequest("PUT", mine, os.time())
        if put and put.StatusCode == 200 then
            local n = readCount()
            if n then setText(label, tostring(math.max(n, 1))) end
        else
            setText(label, "—") -- veritabanı yazma izni yok / bağlantı yok
        end
        for _ = 1, 60 do
            if not alive then break end
            task.wait(1)
        end
    end
    PX.dbRequest("DELETE", mine)
end)

---------------------------------------------------------
-- SCRIPT KULLANICI LOGOSU
-- Aynı sunucuda bu scripti kullanan oyuncular birbirlerinin kafasının üstünde logo görür.
-- Eşleşme için düz Roblox ID'si gönderilmez: yalnızca tuzlu bir özet (hash) + sunucu kimliği
-- ("ezragox_here/<JobId>/<özet>") veritabanına yazılır. Zaman damgası sunucu saatindendir
-- (bilgisayar saati farkı sorun çıkarmaz). Her zaman açıktır, kapatma anahtarı yoktur.
-- Logo ScreenGui katmanında çizilir: Ekran Genişletme etkilemez. Kendi fonksiyonunda çalışır.
---------------------------------------------------------
;(function()
    local LOGO_ID = "rbxassetid://132651627732258"
    local on = true   -- HER ZAMAN AÇIK: kullanıcılar kapatamaz (arayüzde anahtarı yok)
    local dirty = true
    local jobId = (game.JobId ~= "" and game.JobId) or "studio"
    local dbPath = "ezragox_here/" .. string.gsub(jobId, "[^%w%-]", "")

    local function keyOf(userId)
        local str = "ezragox|" .. tostring(userId)
        local h1, h2 = 5381, 7919
        for i = 1, #str do
            local b = string.byte(str, i)
            h1 = (h1 * 31 + b) % 4294967296
            h2 = (h2 * 131 + b) % 4294967291
        end
        return string.format("%08x%08x", h1, h2)
    end

    local myKey = keyOf(LocalPlayer.UserId)
    local users = {}        -- özet -> true (şu an aktif script kullanıcıları)
    local keys = {}         -- Player -> özet (önbellek)
    local marks = {}        -- Player -> ImageLabel
    local layer

    local function ensureLayer()
        if layer and layer.Parent then return layer end
        layer = Instance.new("ScreenGui")
        layer.Name = "EZRAGOX_UserLogoLayer"
        layer.ResetOnSpawn = false
        layer.IgnoreGuiInset = true
        layer.DisplayOrder = 9998
        layer.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        layer.Parent = ScreenGui.Parent or CoreGui
        return layer
    end

    local function dropMark(p)
        local m = marks[p]
        if m then pcall(function() m:Destroy() end) end
        marks[p] = nil
    end

    local function clearMarks()
        for p in pairs(marks) do dropMark(p) end
    end

    local function renderStep()
        if not on then return end
        local cam = workspace.CurrentCamera
        if not cam then return end
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                local k = keys[p]
                if not k then k = keyOf(p.UserId) keys[p] = k end
                local char = p.Character
                local head = char and (char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart"))
                if users[k] and head then
                    local m = marks[p]
                    if not (m and m.Parent) then
                        m = Instance.new("ImageLabel")
                        m.Name = "EZRAGOX_UserLogo"
                        m.BackgroundTransparency = 1
                        m.AnchorPoint = Vector2.new(0.5, 1)
                        m.Size = UDim2.fromOffset(44, 44)
                        m.Image = LOGO_ID
                        m.ScaleType = Enum.ScaleType.Fit
                        m.Visible = false
                        m.Parent = ensureLayer()
                        marks[p] = m
                    end
                    local pnt, vis = cam:WorldToViewportPoint(head.Position + Vector3.new(0, head.Size.Y * 0.5 + 2.4, 0))
                    local show = vis and pnt.Z > 0   -- uzaklık sınırı yok: logo hep kafanın üstünde kalır
                    m.Visible = show
                    if show then m.Position = UDim2.fromOffset(pnt.X, pnt.Y) end
                elseif marks[p] then
                    dropMark(p)
                end
            end
        end
    end

    bind(Players.PlayerRemoving, function(p)
        dropMark(p)
        keys[p] = nil
    end)

    pcall(function() RunService:UnbindFromRenderStep("EZRAGOX_UserLogoPos") end)
    RunService:BindToRenderStep("EZRAGOX_UserLogoPos", Enum.RenderPriority.Camera.Value + 2, function()
        if not alive then return end
        pcall(renderStep)
    end)

    local function sync()
        -- Kendi kaydını sunucu saatiyle yaz, sonra listeyi oku (yaş = benim saatim - onun saati)
        local put = PX.dbRequest("PUT", dbPath .. "/" .. myKey, {[".sv"] = "timestamp"})
        if not (put and put.StatusCode == 200) then return end
        local res = PX.dbRequest("GET", dbPath)
        if not (res and res.StatusCode == 200) or res.Body == nil or res.Body == "null" or res.Body == "" then return end
        local ok, data = pcall(function() return HttpService:JSONDecode(res.Body) end)
        if not (ok and type(data) == "table") then return end
        local mine = tonumber(data[myKey])
        if not mine then return end
        local fresh = {}
        for k, t in pairs(data) do
            if type(t) == "number" and mine - t <= 90000 then fresh[k] = true end
        end
        users = fresh
    end

    task.spawn(function()
        local waited = 0
        local wasOn = false
        while alive do
            if on then
                if dirty or waited >= 10 then
                    dirty, waited = false, 0
                    pcall(sync)
                    wasOn = true
                end
            else
                if wasOn then
                    wasOn = false
                    users = {}
                    PX.dbRequest("DELETE", dbPath .. "/" .. myKey)
                end
                dirty, waited = false, 0
            end
            task.wait(1)
            waited = waited + 1
        end
        pcall(function() RunService:UnbindFromRenderStep("EZRAGOX_UserLogoPos") end)
        clearMarks()
        if layer then pcall(function() layer:Destroy() end) end
        PX.dbRequest("DELETE", dbPath .. "/" .. myKey)
    end)
end)()

---------------------------------------------------------
-- YÖNETİM SEKMESİ (GİZLİ — SADECE ŞİFREYLE AÇILIR)
---------------------------------------------------------
function PX.secret()
    local s = ""
    pcall(function()
        if isfile and readfile and isfile(SECRET_FILE) then s = readfile(SECRET_FILE) end
    end)
    s = s:gsub("%s", "")
    return s
end

function PX.resolveUserId(name)
    local id
    local ok = pcall(function() id = Players:GetUserIdFromNameAsync(name) end)
    if ok and id then return id end
    return nil
end

function PX.addUserRow(name, userId)
    if PX.rows[userId] and PX.rows[userId].Parent then return end
    local btn
    btn = createButton(AdminPage, "👤  " .. name .. "   •   tıkla = premiumu kaldır", function()
        PX.revoke(userId, name)
    end)
    local l = btn:FindFirstChildOfClass("TextLabel")
    if l then l.TextColor3 = Color3.fromRGB(255, 214, 102) end
    PX.rows[userId] = btn
end

function PX.grant(rawName)
    local name = tostring(rawName or "")
    name = name:gsub("%s", "")
    if name == "" then
        notify("Kullanıcı Adı Boş", "Önce bir Roblox kullanıcı adı yaz.", 3)
        return
    end
    task.spawn(function()
        local id = PX.resolveUserId(name)
        if not id then
            notify("Kullanıcı Bulunamadı", "Bu adda bir Roblox hesabı yok: " .. name, 4)
            return
        end
        if KEY_DB_URL == "" then
            PX.copy('"' .. name:lower() .. '",')
            notify("Veritabanı Yok", "Satır panoya kopyalandı: dosyadaki PREMIUM_NAMES listesine ekle.", 6)
            return
        end
        local secret = PX.secret()
        if secret == "" then
            notify("Gizli Anahtar Yok", "Önce veritabanı gizli anahtarını kaydet.", 4)
            return
        end
        local res = PX.dbRequest("PUT", "ezragox_premium/" .. id, {name = name, grantedAt = os.time()}, secret)
        if res and res.StatusCode == 200 then
            notify("Premium Verildi 👑", name .. "  (" .. id .. ")", 4)
            PX.addUserRow(name, id)
        else
            notify("Hata", "Veritabanına yazılamadı. Adres ve gizli anahtarı kontrol et.", 5)
        end
    end)
end

function PX.revoke(userId, name)
    task.spawn(function()
        if KEY_DB_URL == "" then
            notify("Veritabanı Yok", "Listeden elle sil: PREMIUM_NAMES.", 4)
            return
        end
        local secret = PX.secret()
        if secret == "" then
            notify("Gizli Anahtar Yok", "Önce veritabanı gizli anahtarını kaydet.", 4)
            return
        end
        local res = PX.dbRequest("DELETE", "ezragox_premium/" .. userId, nil, secret)
        if res and res.StatusCode == 200 then
            notify("Premium Kaldırıldı", tostring(name or userId), 3)
            PX.checkPremium(true)
            local row = PX.rows[userId]
            if row then row:Destroy() end
            PX.rows[userId] = nil
        else
            notify("Hata", "Veritabanından silinemedi.", 4)
        end
    end)
end

function PX.loadList()
    task.spawn(function()
        local res = PX.dbRequest("GET", "ezragox_premium")
        if not res or res.StatusCode ~= 200 then
            notify("Liste Alınamadı", "Veritabanı adresini kontrol et.", 4)
            return
        end
        if res.Body == "null" then
            notify("Liste Boş", "Henüz premium verilen hesap yok.", 3)
            return
        end
        local ok, data = pcall(function() return HttpService:JSONDecode(res.Body) end)
        if not ok or type(data) ~= "table" then return end
        local n = 0
        for id, v in pairs(data) do
            local uid = tonumber(id)
            if uid then
                PX.addUserRow((type(v) == "table" and v.name) or tostring(uid), uid)
                n = n + 1
            end
        end
        notify("Liste Yüklendi", n .. " hesap bulundu.", 3)
    end)
end

createSection(AdminPage, "PREMİUM YÖNETİMİ")
PX.infoCard(AdminPage, trText("🛡️  Sadece sana özel"), trText("Premium vermek istediğin kişinin Roblox kullanıcı adını yaz. Premium o hesaba tanımlanır; kişi menüyü açınca kendi hesabıyla otomatik premium olur."), 84)
local _, userBox = PX.inputRow(AdminPage, "Kullanıcı", "Roblox kullanıcı adı (örn: hasanusta_03)")
createButton(AdminPage, "✅  Premium Ver", function() PX.grant(userBox.Text) end)
createButton(AdminPage, "❌  Premium Kaldır", function()
    local name = userBox.Text:gsub("%s", "")
    if name == "" then
        notify("Kullanıcı Adı Boş", "Önce bir Roblox kullanıcı adı yaz.", 3)
        return
    end
    task.spawn(function()
        local id = PX.resolveUserId(name)
        if id then
            PX.revoke(id, name)
        else
            notify("Kullanıcı Bulunamadı", name, 3)
        end
    end)
end)
createButton(AdminPage, "📜  Premium Listesini Yükle", function() PX.loadList() end)

-- DUYURU: Yönetici gönderir; açık EZRAGOX istemcileri ortak veritabanından alır.
createSection(AdminPage, "📢  TÜM KULLANICILARA DUYURU")
local _, announcementBox = PX.inputRow(AdminPage, "Duyuru", "Gönderilecek mesajı yaz...")
local locallyDisplayedAnnouncementId = nil
createButton(AdminPage, "📢  Duyuruyu Herkese Gönder", function()
    local message = tostring(announcementBox.Text or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if message == "" then
        notify("Duyuru Boş", "Önce gönderilecek duyuru metnini yaz.", 3)
        return
    end
    if #message > 400 then
        notify("Duyuru Çok Uzun", "Duyuru en fazla 400 karakter olabilir.", 3)
        return
    end
    if KEY_DB_URL == "" then
        notify("Veritabanı Yok", "Duyuru göndermek için ortak veritabanı gerekli.", 4)
        return
    end
    local secret = PX.secret()
    if secret == "" then
        notify("Gizli Anahtar Yok", "Önce veritabanı gizli anahtarını kaydet.", 4)
        return
    end
    task.spawn(function()
        local payload = {
            message = message,
            title = "EZRAGOX HUB • DUYURU",
            sender = LocalPlayer.Name,
            sentAt = os.time(),
            id = HttpService:GenerateGUID(false),
        }
        local result = PX.dbRequest("PUT", "ezragox_announcements/latest", payload, secret)
        if result and result.StatusCode == 200 then
            -- Gönderen de diğer kullanıcılarla aynı duyuru bildirimini görür.
            locallyDisplayedAnnouncementId = tostring(payload.id)
            notify(tostring(payload.title), tostring(payload.message), 8)
            notify("Duyuru Gönderildi", "Duyuru ortak veritabanına kaydedildi.", 3)
            announcementBox.Text = ""
        else
            notify("Duyuru Gönderilemedi", "Veritabanı bağlantısını ve gizli anahtarı kontrol et.", 5)
        end
    end)
end)

-- İstemci tarafı alıcı: son duyuruyu düzenli aralıklarla kontrol eder.
task.spawn(function()
    local lastAnnouncementId = nil
    local firstRead = true
    while alive do
        task.wait(8)
        if not alive or KEY_DB_URL == "" then break end
        local response = PX.dbRequest("GET", "ezragox_announcements/latest")
        if response and response.StatusCode == 200 and response.Body and response.Body ~= "null" then
            local ok, announcement = pcall(function()
                return HttpService:JSONDecode(response.Body)
            end)
            if ok and type(announcement) == "table" then
                local id = tostring(announcement.id or announcement.sentAt or "")
                if id ~= "" then
                    if firstRead then
                        lastAnnouncementId = id
                        firstRead = false
                    elseif id ~= lastAnnouncementId then
                        lastAnnouncementId = id
                        local message = tostring(announcement.message or "")
                        -- Gönderenin kendi ekranında zaten gösterilen duyuruyu ikinci kez çıkarma.
                        if message ~= "" and id ~= locallyDisplayedAnnouncementId then
                            notify(tostring(announcement.title or "EZRAGOX HUB • DUYURU"), message, 8)
                        end
                    end
                end
            end
        end
    end
end)

createSection(AdminPage, "VERİTABANI GİZLİ ANAHTARI  (sadece bu cihazda saklanır)")
local _, secretBox = PX.inputRow(AdminPage, "Gizli Anahtar", "Firebase veritabanı gizli anahtarı")
createButton(AdminPage, "💾  Gizli Anahtarı Kaydet", function()
    local v = secretBox.Text:gsub("%s", "")
    if v == "" then
        notify("Boş", "Gizli anahtarı yapıştır.", 3)
        return
    end
    local ok = pcall(function() writefile(SECRET_FILE, v) end)
    setText(secretBox, "")
    notify(ok and "Kaydedildi" or "Kaydedilemedi", ok and "Gizli anahtar bu cihaza kaydedildi." or "Executor dosya yazmayı desteklemiyor.", 3)
end)
createButton(AdminPage, "🔒  Yönetimi Kilitle ve Gizle", function() PX.lockAdmin() end)
createSection(AdminPage, "PREMİUM OLAN HESAPLAR  (tıkla = kaldır)")

function PX.lockAdmin()
    PX.admin = false
    PX.adminTab.btn.Visible = false
    PX.setPremium(false)
    task.spawn(function() PX.checkPremium(true) end)
    selectTab(Tabs[1])
    notify("Yönetim Kilitlendi", "Sekme gizlendi.", 3)
end

---------------------------------------------------------
-- YÖNETİM ŞİFRE PENCERESİ + GİZLİ AÇMA YÖNTEMLERİ
---------------------------------------------------------
do
    local dim = new("TextButton", {
        Name = "EZRAGOX_AdminPrompt", Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 0.35, AutoButtonColor = false, Text = "", Visible = false, ZIndex = 60,
    }, MainFrame)
    corner(dim, 22)
    local card = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(0, 320, 0, 186),
        BackgroundColor3 = Color3.fromRGB(18, 9, 14), BorderSizePixel = 0, ZIndex = 61,
    }, dim)
    corner(card, 16)
    stroke(card, 1.5, Color3.fromRGB(255, 50, 68), 0.2)
    new("TextLabel", {
        Position = UDim2.new(0, 16, 0, 14), Size = UDim2.new(1, -32, 0, 22), BackgroundTransparency = 1,
        Text = "🛡️  YÖNETİM GİRİŞİ", Font = Enum.Font.GothamBlack, TextSize = 16, TextColor3 = Color3.new(1, 1, 1),
        TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 62,
    }, card)
    new("TextLabel", {
        Position = UDim2.new(0, 16, 0, 40), Size = UDim2.new(1, -32, 0, 16), BackgroundTransparency = 1,
        Text = "Devam etmek için yönetim şifresini gir.", Font = Enum.Font.GothamMedium, TextSize = 12,
        TextColor3 = Color3.fromRGB(150, 163, 195), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 62,
    }, card)
    local box = new("TextBox", {
        Position = UDim2.new(0, 16, 0, 68), Size = UDim2.new(1, -32, 0, 38), BackgroundColor3 = Color3.fromRGB(28, 14, 20),
        Text = "", PlaceholderText = "Şifre", PlaceholderColor3 = Color3.fromRGB(130, 100, 108),
        TextColor3 = Color3.fromRGB(255, 214, 102), TextSize = 18, Font = Enum.Font.Code,
        ClearTextOnFocus = true, ZIndex = 62,
    }, card)
    corner(box, 10)
    stroke(box, 1, Color3.fromRGB(135, 40, 55), 0.3)
    local enter = new("TextButton", {
        Position = UDim2.new(0, 16, 1, -56), Size = UDim2.new(0.5, -22, 0, 38), BackgroundColor3 = Color3.fromRGB(190, 18, 42),
        Text = "Giriş", Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = Color3.new(1, 1, 1),
        AutoButtonColor = false, ZIndex = 62,
    }, card)
    corner(enter, 10)
    ctaFx(enter, {radius = 10})
    local cancel = new("TextButton", {
        AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 1, -56), Size = UDim2.new(0.5, -22, 0, 38),
        BackgroundColor3 = Color3.fromRGB(45, 24, 30), Text = "İptal", Font = Enum.Font.GothamBold, TextSize = 14,
        TextColor3 = Color3.fromRGB(220, 200, 205), AutoButtonColor = false, ZIndex = 62,
    }, card)
    corner(cancel, 10)
    ctaFx(cancel, {radius = 10})

    -- Yazılanı yıldızla gizle (omuz üstünden / kayıttan görünmesin)
    local busy = false
    bind(box:GetPropertyChangedSignal("Text"), function()
        if busy then return end
        local t = box.Text
        if #t > #PX.real then
            PX.real = PX.real .. t:sub(#PX.real + 1)
        else
            PX.real = PX.real:sub(1, #t)
        end
        busy = true
        setText(box, string.rep("*", #PX.real))
        busy = false
    end)

    function PX.hidePrompt()
        dim.Visible = false
        PX.real = ""
        busy = true
        setText(box, "")
        busy = false
    end

    function PX.showPrompt()
        if not menuOpen then return end
        PX.real = ""
        busy = true
        setText(box, "")
        busy = false
        dim.Visible = true
        task.defer(function() pcall(function() box:CaptureFocus() end) end)
    end

    function PX.submitAdmin()
        if os.clock() < PX.adminCooldownUntil then
            notify("Biraz Bekle", "Çok fazla hatalı deneme. Bir süre sonra tekrar dene.", 3)
            return
        end
        if PX.checkAdmin(PX.real) then
            PX.adminWrong = 0
            PX.admin = true
            PX.hidePrompt()
            PX.adminTab.btn.Visible = true
            PX.setPremium(true, true)
            selectTab(PX.adminTab)
            notify("Yönetim Açıldı 🛡️", "Hoş geldin! Premium da senin için açıldı.", 4)
        else
            PX.adminWrong = PX.adminWrong + 1
            PX.real = ""
            busy = true
            setText(box, "")
            busy = false
            if PX.adminWrong >= 3 then
                PX.adminWrong = 0
                PX.adminCooldownUntil = os.clock() + 30
                PX.hidePrompt()
                notify("Erişim Engellendi", "3 hatalı deneme. 30 saniye bekle.", 4)
            else
                notify("Şifre Hatalı", "Tekrar dene.", 2)
            end
        end
    end

    bind(enter.MouseButton1Click, function()
        playClickSound()
        PX.submitAdmin()
    end)
    bind(cancel.MouseButton1Click, function()
        playClickSound()
        PX.hidePrompt()
    end)
    bind(box.FocusLost, function(enterPressed)
        if enterPressed then PX.submitAdmin() end
    end)
end

-- Gizli açma yöntemi 1: Ctrl + Shift + Y
bind(UserInputService.InputBegan, function(input, gpe)
    if gpe or not ready or not menuOpen then return end
    if input.KeyCode == ADMIN_HOTKEY
        and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
        and UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
        if PX.admin then
            selectTab(PX.adminTab)
        else
            PX.showPrompt()
        end
    end
end)

-- Gizli açma yöntemi 2 (mobil/klavyesiz): sol paneldeki küçük "menüyü aç/kapat" yazısına hızlıca 7 kez dokun
do
    local taps, lastTap = 0, 0
    SidebarKeyHint.Active = true
    bind(SidebarKeyHint.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            local now = os.clock()
            if now - lastTap > 1.2 then taps = 0 end
            lastTap = now
            taps = taps + 1
            if taps >= 7 then
                taps = 0
                if PX.admin then
                    selectTab(PX.adminTab)
                else
                    PX.showPrompt()
                end
            end
        end
    end)
end

-- Yönetim sekmesi başlangıçta tamamen gizli
PX.adminTab.btn.Visible = false
end

-- OYUN BAŞLANGICI BİLDİRİMİ: sürekli tarama yapmaz.
-- Arayüz bir kez kontrol edilir; sonrasında yalnızca yeni/değişen metin etiketleri izlenir.
task.spawn(function()
    local playerGui = LocalPlayer:WaitForChild("PlayerGui", 15)
    if not playerGui then return end
    local alreadyNotified = false
    local watched = setmetatable({}, {__mode = "k"})
    local function inspectText(obj)
        if not (obj and (obj:IsA("TextLabel") or obj:IsA("TextButton"))) then return end
        local value = string.lower(tostring(obj.Text or ""))
        if value == "" then return end
        if string.find(value, "waiting for players", 1, true)
            or string.find(value, "intermission", 1, true)
            or string.find(value, "lobby", 1, true)
            or string.find(value, "bekleyen oyuncu", 1, true)
            or string.find(value, "lobi", 1, true) then
            alreadyNotified = false
        end
        if not alreadyNotified and (
            string.find(value, "your role", 1, true)
            or string.find(value, "you are the murderer", 1, true)
            or string.find(value, "you are innocent", 1, true)
            or string.find(value, "you are sheriff", 1, true)
            or string.find(value, "round started", 1, true)
            or string.find(value, "game started", 1, true)
            or string.find(value, "oyun başladı", 1, true)
            or string.find(value, "tur başladı", 1, true)
        ) then
            alreadyNotified = true
            notify("OYUN BAŞLADI", "Dikkatli ol!", 4)
        end
    end
    local function watch(obj)
        if watched[obj] then return end
        if not (obj:IsA("TextLabel") or obj:IsA("TextButton")) then return end
        watched[obj] = true
        pcall(function()
            obj:GetPropertyChangedSignal("Text"):Connect(function()
                if alive then inspectText(obj) end
            end)
        end)
        inspectText(obj)
    end
    -- Tek seferlik başlangıç kontrolü.
    for _, obj in ipairs(playerGui:GetDescendants()) do
        watch(obj)
    end
    -- Bundan sonra yalnızca eklenen GUI nesneleri izlenir; periyodik tarama yoktur.
    playerGui.DescendantAdded:Connect(function(obj)
        if alive then watch(obj) end
    end)
end)

-- AYARLAR
createSection(SettingsPage, "KONTROL")
do
    local row, st = baseRow(SettingsPage, "TextButton", 42)
    rowLabel(row, "Menü Tuşu")
    local keyText = new("TextLabel", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.new(0, 100, 0, 26),
        BackgroundTransparency = 1, Text = Settings.ToggleKey.Name, Font = Enum.Font.GothamBold, TextSize = 13,
        TextColor3 = Color3.fromRGB(255, 65, 75), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 4,
    }, row)
    hoverFx(row, st)

    updateKeyTextCallback = function(name)
        setText(keyText, name)
    end

    bind(row.MouseButton1Click, function()
        playClickSound()
        listeningForKey = true
        setText(keyText, "Tuşa basın...")
        notify("Tuş Bekleniyor", "Menü için yeni bir klavye tuşuna basın...", 3)
    end)
end

createSection(SettingsPage, "GÖRÜNÜM")
createToggle(SettingsPage, "Bulanık arka plan", Settings.Blur, function(v)
    Settings.Blur = v
    if menuOpen then
        if v then
            blurEffect.Enabled = true
            tween(blurEffect, 0.3, {Size = 12})
        else
            tween(blurEffect, 0.3, {Size = 0})
            task.delay(0.3, function() if not Settings.Blur then blurEffect.Enabled = false end end)
        end
    end
end)
createSlider(SettingsPage, "Menü boyutu", 60, 120, math.floor(Settings.Scale * 100 + 0.5), function(v)
    Settings.Scale = v / 100
    if menuOpen then tween(MainScale, 0.15, {Scale = menuScale()}) end
end, "%")
createSection(SettingsPage, "SES")
createToggle(SettingsPage, "Ses efektleri", Settings.Sound, function(v) Settings.Sound = v end)
createSlider(SettingsPage, "Bildirim sesi seviyesi", 0, 100, Settings.NotificationVolume or 35, function(v)
    Settings.NotificationVolume = v
    saveConfig()
end, "%")
createSection(SettingsPage, "DİĞER")
createButton(SettingsPage, "Menüyü küçült", function() setMenu(false) end)
createButton(SettingsPage, "Arayüzü tamamen kapat", function() closeAll() end)

-- DİL SEÇİMİ
createSection(SettingsPage, "DİL / LANGUAGE")
do
    local row, st = baseRow(SettingsPage, "Frame", 48)
    rowLabel(row, "Dil / Language")
    -- Background layers carry the animated color effect; button text stays plain white.
    local trBg = new("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -106, 0.5, 0),
        Size = UDim2.new(0, 82, 0, 30),
        BackgroundColor3 = Color3.fromRGB(120, 22, 38),
        BorderSizePixel = 0,
        ZIndex = 5,
    }, row)
    corner(trBg, 8)
    local trGradient = new("UIGradient", {
        Color = flowSeq(0.1, 0.55),
        Rotation = 0,
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.22),
            NumberSequenceKeypoint.new(0.5, 0.02),
            NumberSequenceKeypoint.new(1, 0.22),
        }),
    }, trBg)
    regFlow(UIFlows, trGradient, 0.1, 0.55, 36)
    local trStroke = stroke(trBg, 1.2, Color3.fromRGB(190, 65, 80), 0.25)

    local trButton = new("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -106, 0.5, 0),
        Size = UDim2.new(0, 82, 0, 30),
        BackgroundTransparency = 1,
        Text = "Türkçe",
        TextColor3 = Color3.fromRGB(255, 255, 255),
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        AutoButtonColor = false,
        ZIndex = 6,
    }, row)

    local enBg = new("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -12, 0.5, 0),
        Size = UDim2.new(0, 82, 0, 30),
        BackgroundColor3 = Color3.fromRGB(35, 42, 58),
        BorderSizePixel = 0,
        ZIndex = 5,
    }, row)
    corner(enBg, 8)
    local enGradient = new("UIGradient", {
        Color = flowSeq(1.7, 0.55),
        Rotation = 0,
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.22),
            NumberSequenceKeypoint.new(0.5, 0.02),
            NumberSequenceKeypoint.new(1, 0.22),
        }),
    }, enBg)
    regFlow(UIFlows, enGradient, 1.7, 0.55, 36)
    local enStroke = stroke(enBg, 1.2, Color3.fromRGB(90, 105, 130), 0.25)

    local enButton = new("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -12, 0.5, 0),
        Size = UDim2.new(0, 82, 0, 30),
        BackgroundTransparency = 1,
        Text = "English",
        TextColor3 = Color3.fromRGB(255, 255, 255),
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        AutoButtonColor = false,
        ZIndex = 6,
    }, row)

    ctaFx(trButton, {visual = trBg, also = {trButton}, radius = 8, colors = false})
    ctaFx(enButton, {visual = enBg, also = {enButton}, radius = 8, colors = false})

    local function refreshLanguageButtons(code)
        local trSelected = code == "TR"
        local enSelected = code == "EN"

        trBg.BackgroundTransparency = 0
        enBg.BackgroundTransparency = 0
        trBg.BackgroundColor3 = trSelected and Color3.fromRGB(120, 22, 38) or Color3.fromRGB(35, 42, 58)
        enBg.BackgroundColor3 = enSelected and Color3.fromRGB(120, 22, 38) or Color3.fromRGB(35, 42, 58)

        -- The animated gradient remains behind both labels, regardless of selection.
        trGradient.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, trSelected and 0.12 or 0.48),
            NumberSequenceKeypoint.new(0.5, trSelected and 0.02 or 0.22),
            NumberSequenceKeypoint.new(1, trSelected and 0.12 or 0.48),
        })
        enGradient.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, enSelected and 0.12 or 0.48),
            NumberSequenceKeypoint.new(0.5, enSelected and 0.02 or 0.22),
            NumberSequenceKeypoint.new(1, enSelected and 0.12 or 0.48),
        })

        trStroke.Transparency = trSelected and 0.05 or 0.35
        enStroke.Transparency = enSelected and 0.05 or 0.35
        trStroke.Color = trSelected and Color3.fromRGB(255, 95, 110) or Color3.fromRGB(115, 125, 145)
        enStroke.Color = enSelected and Color3.fromRGB(255, 95, 110) or Color3.fromRGB(115, 125, 145)

        -- Both labels are always simple, solid white.
        trButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        enButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    end

    local function chooseLanguage(code)
        Settings.Language = code
        saveConfig()
        applyLanguage()
        refreshLanguageButtons(code)
        notify("EZRAGOX HUB", code == "EN" and "Language changed to English." or "Dil Türkçe olarak değiştirildi.", 2)
    end
    bind(trButton.MouseButton1Click, function() chooseLanguage("TR") end)
    bind(enButton.MouseButton1Click, function() chooseLanguage("EN") end)
    refreshLanguageButtons(Settings.Language)
end

selectTab(Tabs[1])

---------------------------------------------------------
-- 10. HER KARE GÜNCELLEMELER
---------------------------------------------------------
local fps, fpsAcc, fpsN = 60, 0, 0

local animAcc = 0
bind(RunService.RenderStepped, function(rawDt)
    local t = os.clock()
    fpsAcc = fpsAcc + rawDt
    fpsN = fpsN + 1
    if fpsAcc >= 0.5 then
        fps = math.floor(fpsN / fpsAcc + 0.5)
        fpsAcc, fpsN = 0, 0
    end

    -- Performans: menü kapalıyken animasyonlar ~12 Hz'e iner; menü açıkken (çok yüksek FPS dışında)
    -- her karede çalışır, görünüm aynı kalır.
    animAcc = animAcc + rawDt
    local interval = menuOpen and (1 / 30) or (1 / 12)
    if animAcc < interval then return end
    local dt = animAcc
    animAcc = 0

    -- Performans: ayni degerleri paylasan nesneler icin hesap tek sefer yapilir (GC baskisi azalir)
    local accCache, seqCache = {}, {}
    for _, a in ipairs(UIAccents) do
        local c = accCache[a.off]
        if not c then c = accentAt(a.off); accCache[a.off] = c end
        a.obj[a.prop] = c
    end
    for _, f in ipairs(UIFlows) do
        local seq = seqCache[f.key]
        if not seq then seq = flowSeq(f.phase, f.step); seqCache[f.key] = seq end
        f.grad.Color = seq
        if f.spin then f.grad.Rotation = (f.grad.Rotation + f.spin * dt) % 360 end
    end
    for _, p in ipairs(Pulsers) do p.obj[p.prop] = p.base + math.sin(t * p.speed) * p.amp end

end)

local function getPing()
    local ok, v = pcall(function()
        return math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue() + 0.5)
    end)
    return ok and v or nil
end
task.spawn(function()
    while alive do
        if menuOpen then
            -- Ultra FPS açıkken ana sayfa göstergesine +100 eklenir.
            -- Gerçek FPS ölçümü ve oyun performansı değiştirilmez.
            local displayedFps = math.max(0, math.floor(fps)) + (ultraFpsDisplayBoost and 100 or 0)
            setText(FpsValue, tostring(displayedFps))
            local ping = getPing()
            setText(PingValue, ping and (tostring(ping) .. " ms") or "—")
            setText(PlayersValue, tostring(#Players:GetPlayers()))
        end
        task.wait(0.5)
    end
end)

task.spawn(function()
    while alive do
        task.wait(2.8)
        if menuOpen then
            for _, s in ipairs(Shines) do
                if s.Parent then playShine(s) end
            end
        end
    end
end)

---------------------------------------------------------
-- 11. SİNEMATİK GİRİŞ SENARYOSU
---------------------------------------------------------
task.spawn(function()
    -- Karşılama sesi menü açılırken değil, giriş başladıktan 6.5 sn sonra çalar
    task.delay(6.5, function()
        if alive then playMenuIntroSoundOnce() end
    end)
    Intro.play(function()
        -- Flaşın tepe noktasında ana menü açılır
        ready = true
        menuOpen = true
        MainFrame.Visible = true
        MenuCharViewport.Visible = true
        MenuFX.open(true)
        if Settings.Blur then
            tween(blurEffect, 0.6, {Size = 12})
        else
            tween(blurEffect, 0.6, {Size = 0})
            task.delay(0.6, function() if not menuOpen or not Settings.Blur then blurEffect.Enabled = false end end)
        end
        playClickSound()
        task.delay(0.8, function()
            notify("EZRAGOX HUB", "Hoş geldin! Menüyü " .. Settings.ToggleKey.Name .. " tuşu ile açıp kapatabilirsin.", 4)
        end)
    end)
end)
