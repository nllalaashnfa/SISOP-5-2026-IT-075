# Sisop-5-2026-IT-075


| Nama | NRP |
|------|-----|
| Nayla Aisha Hanifa | 5027251075 |
---

## Soal 2 — Season (Final Challenge)

### Deskripsi Soal

Pada soal ini kita diminta untuk membuat sebuah **mini sistem operasi sederhana** yang berjalan langsung di atas mesin (tanpa OS lain seperti Windows atau Linux di bawahnya). Sistem ini memiliki tampilan command-line (seperti Terminal/CMD) yang bisa menerima perintah dari user.

File yang boleh diedit hanya dua:
- `kernel.asm` — kode assembly sebagai jembatan antara hardware dan kode C
- `kernel.c` — kode C yang berisi semua logika perintah dan tampilan layar

Cara build dan run:
```
make build   ← untuk mengkompilasi semua file
make run     ← untuk menjalankan di emulator Bochs
```


```
Komputer nyala
      ↓
    BIOS
      ↓
  Bootloader    ← dibaca dari sektor pertama floppy disk
      ↓
    Kernel      ← dimuat ke memori, lalu dijalankan
      ↓
  Tampilan shell (command line)
      ↓
  User bisa ketik perintah
```

---

### A. Bootloader — `bootloader.asm`

Bootloader adalah program pertama yang dijalankan setelah BIOS. Ukurannya hanya 512 byte (1 sektor disk). Tugasnya adalah memuat kernel dari disk ke memori, lalu menyerahkan kendali ke kernel.

```asm
bits 16
org 0x7C00
```

`bits 16` artinya kode ini ditulis untuk mode 16-bit (mode awal saat komputer baru nyala). `org 0x7C00` artinya program ini akan diletakkan di alamat memori `0x7C00` — BIOS selalu menaruh bootloader di sini.

```asm
KERNEL_SEGMENT equ 0x1000
KERNEL_SECTORS equ 15
```

Dua konstanta ini dipakai nanti:
- `KERNEL_SEGMENT = 0x1000` → alamat memori tempat kernel akan diletakkan
- `KERNEL_SECTORS = 15` → kernel terdiri dari 15 sektor (15 × 512 byte = 7.680 byte)

#### Inisialisasi Register

```asm
start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00
    sti
```

- `cli` → matikan interrupt dulu supaya proses setup tidak terganggu
- `xor ax, ax` → buat register AX bernilai 0 (trik cepat isi nol)
- `mov ds, ax` / `mov es, ax` / `mov ss, ax` → set semua register segmen ke 0
- `mov sp, 0x7C00` → tentukan lokasi stack (tumpukan data sementara) tepat di bawah bootloader
- `sti` → nyalakan kembali interrupt

#### Baca Kernel dari Disk

```asm
    mov ax, KERNEL_SEGMENT
    mov es, ax
    xor bx, bx

    mov ah, 0x02
    mov al, KERNEL_SECTORS
    mov ch, 0x00
    mov cl, 0x02
    mov dh, 0x00

    int 0x13
    jc disk_error
```

Bagian ini menggunakan **layanan BIOS nomor 0x13** untuk membaca isi disk:
- `ah = 0x02` → perintah "baca sektor"
- `al = 15` → baca sebanyak 15 sektor
- `ch = 0, cl = 2` → mulai dari silinder 0, sektor 2 (sektor 1 sudah dipakai bootloader)
- `dh = 0` → head 0
- `ES:BX = 0x1000:0x0000` → taruh hasilnya di memori alamat ini
- `int 0x13` → panggil layanan BIOS
- `jc disk_error` → kalau gagal (carry flag = 1), lompat ke tampilan error

#### Lompat ke Kernel

```asm
    push word KERNEL_SEGMENT
    push word 0x0000
    retf
```

Setelah kernel berhasil dimuat ke memori, bootloader lompat ke alamat kernel menggunakan trik `push` + `retf` (far return). Ini sama artinya dengan "lompat ke alamat `0x1000:0x0000`" tempat kernel berada.

#### Error Handler

```asm
disk_error:
    mov si, msg
.print:
    lodsb
    or al, al
    jz $
    mov ah, 0x0E
    mov bh, 0x00
    int 0x10
    jmp .print
msg db 'DISK ERROR',0
```

Kalau pembacaan disk gagal, bootloader menampilkan tulisan `DISK ERROR` di layar menggunakan layanan BIOS nomor `0x10` (layanan video), lalu berhenti.

#### Tanda Tangan Bootloader

```asm
times 510-($-$$) db 0
dw 0xAA55
```

BIOS hanya mau menjalankan bootloader kalau 2 byte terakhir dari 512 byte adalah `0xAA55`. Baris `times 510-($-$$) db 0` mengisi sisa ruang dengan nol sampai tepat 510 byte, lalu `dw 0xAA55` menambahkan tanda tangan wajib tersebut.

---

### B. Entry Point Kernel — `kernel.asm`

Setelah bootloader lompat ke kernel, yang pertama dijalankan adalah `_start` di file `kernel.asm`. File ini berperan sebagai jembatan antara kode Assembly dan kode C.

```asm
bits 16

global _start
global _putInMemory
global _getChar
extern _main
```

- `global _start` → beritahu linker bahwa `_start` bisa diakses dari luar
- `global _putInMemory` dan `global _getChar` → fungsi-fungsi assembly ini bisa dipanggil dari kode C
- `extern _main` → fungsi `main()` ada di file `kernel.c`

#### Fungsi `_start` — Titik Awal Kernel

```asm
_start:
    cli
    mov ax, cs
    mov ds, ax
    mov es, ax
    sti
    call _main

.hang:
    jmp .hang
```

Ini adalah instruksi pertama yang dijalankan setelah bootloader menyerahkan kendali:
1. Matikan interrupt sementara
2. Selaraskan register segmen DS dan ES dengan CS (Code Segment) agar kernel bisa baca datanya sendiri
3. Nyalakan interrupt kembali
4. Panggil fungsi `main()` yang ada di `kernel.c`
5. Kalau `main()` selesai (seharusnya tidak, karena ada loop tak terbatas di sana), CPU akan terjebak di `.hang` supaya tidak menjalankan instruksi acak

#### Fungsi `_putInMemory` — Tulis Karakter ke Layar

```asm
_putInMemory:
    push bp
    mov bp, sp
    push ds
    mov ax, [bp+4]    ← parameter 1: segment
    mov si, [bp+6]    ← parameter 2: alamat offset
    mov cl, [bp+8]    ← parameter 3: karakter yang ditulis
    mov ds, ax
    mov [si], cl      ← tulis karakter ke memori
    pop ds
    pop bp
    ret
```

Fungsi ini dipanggil dari kode C dengan format: `putInMemory(segment, address, character)`.

Cara kerja layar di mode teks VGA: layar 80×25 karakter dipetakan ke memori mulai dari alamat `0xB800:0000`. Setiap karakter butuh **2 byte** — byte pertama adalah karakter ASCII, byte kedua adalah warna. Jadi untuk menulis ke layar, cukup tulis ke memori di alamat tersebut.

Dengan mengubah register DS ke segment yang dituju, instruksi `mov [si], cl` bisa menulis ke segmen memori manapun — termasuk memori video layar.

#### Fungsi `_getChar` — Baca Tombol dari Keyboard

```asm
_getChar:
    push bp
    mov bp, sp
    mov ah, 0x00
    int 0x16         ← minta BIOS bacakan tombol keyboard
    xor ah, ah       ← bersihkan scan code, sisakan karakter ASCII saja
    pop bp
    ret
```

Fungsi ini menggunakan **layanan BIOS nomor 0x16** untuk membaca tombol yang ditekan user. Hasilnya adalah kode ASCII dari tombol tersebut. `xor ah, ah` membersihkan bagian scan code agar hanya karakter ASCII yang dikembalikan ke kode C.

---

### C. Kernel Utama — `kernel.c`

File ini berisi semua logika program: tampilan layar, baca input, dan semua perintah yang bisa dijalankan user.

#### Variabel Global

```c
int cursor = 0;
char color = 0x07;
```

- `cursor` → posisi karakter saat ini di layar (0 sampai 1999 untuk layar 80×25)
- `color` → warna teks. `0x07` = teks putih/abu di latar hitam. Nilai ini bisa berubah saat user mengetik perintah `season`

#### Fungsi Tampilan Layar

**`printChar` — Tampilkan Satu Karakter**

```c
void printChar(char c) {
    putInMemory(0xB800, cursor * 2,     c);
    putInMemory(0xB800, cursor * 2 + 1, color);
    cursor++;
}
```

Menulis satu karakter ke layar. `0xB800` adalah alamat awal memori video VGA. Setiap posisi karakter butuh 2 byte: byte pertama isi karakter, byte kedua isi warna. Setelah menulis, `cursor` maju satu posisi ke kanan.

**`newline` — Pindah ke Baris Baru**

```c
void newline() {
    int col = cursor;
    while (col >= 80) {
        col = col - 80;
    }
    cursor = cursor + (80 - col);
}
```

Fungsi ini menghitung posisi kolom saat ini (dengan cara mengurangi 80 berulang-ulang sampai kurang dari 80, karena tiap baris ada 80 karakter), lalu menggeser cursor ke awal baris berikutnya. Cara manual ini dipakai karena tidak ada operator `%` (modulo) yang tersedia di lingkungan bare-metal ini.

**`printString` — Tampilkan Kalimat**

```c
void printString(char *str) {
    int i = 0;
    while (str[i] != '\0') {
        if (str[i] == '\n') {
            newline();
        } else {
            printChar(str[i]);
        }
        i++;
    }
}
```

Menampilkan string karakter per karakter. Kalau menemukan karakter `\n` (newline), panggil fungsi `newline()`. Kalau karakter biasa, panggil `printChar()`. Berhenti saat menemukan `\0` (penanda akhir string).

**`clearScreen` — Bersihkan Layar**

```c
void clearScreen() {
    int i;
    for (i = 0; i < 2000; i++) {
        putInMemory(0xB800, i * 2,     ' ');
        putInMemory(0xB800, i * 2 + 1, color);
    }
    cursor = 0;
}
```

Mengisi semua 2000 posisi karakter (80 kolom × 25 baris = 2000) dengan karakter spasi, sehingga layar tampak kosong. Setelah itu cursor kembali ke pojok kiri atas (posisi 0).

**`readString` — Baca Input dari Keyboard**

```c
void readString(char *buf) {
    int i = 0;
    char c;
    while (1) {
        c = getChar();
        if (c == '\r') {
            buf[i] = '\0';
            break;
        } else if (c == '\b') {
            if (i > 0) {
                i--;
                cursor--;
                putInMemory(0xB800, cursor * 2,     ' ');
                putInMemory(0xB800, cursor * 2 + 1, color);
            }
        } else {
            buf[i] = c;
            i++;
            printChar(c);
        }
    }
}
```

Membaca input keyboard satu karakter per satu karakter:
- Kalau user tekan **Enter** (`\r`) → hentikan pembacaan, simpan `\0` sebagai penanda akhir string
- Kalau user tekan **Backspace** (`\b`) → hapus karakter terakhir dari buffer dan hapus tampilannya di layar
- Karakter biasa → simpan ke buffer dan tampilkan di layar (echo)

---

#### Fungsi-Fungsi Pembantu

Karena di bare-metal tidak ada library standar C (tidak ada `stdio.h`, `string.h`, dll), semua fungsi umum harus dibuat sendiri.

**`strcmp` — Bandingkan Dua String**

```c
int strcmp(char *a, char *b) {
    int i = 0;
    while (a[i] != '\0' && b[i] != '\0') {
        if (a[i] != b[i]) return 0;
        i++;
    }
    return a[i] == '\0' && b[i] == '\0';
}
```

Membandingkan string `a` dan `b` karakter per karakter. Mengembalikan `1` kalau kedua string sama persis, `0` kalau berbeda. Catatan: berbeda dari `strcmp` bawaan C yang mengembalikan 0 kalau sama.

**`startsWith` — Cek Awalan String**

```c
int startsWith(char *str, char *prefix) {
    int i = 0;
    while (prefix[i] != '\0') {
        if (str[i] != prefix[i]) return 0;
        i++;
    }
    return 1;
}
```

Mengecek apakah string `str` diawali dengan `prefix`. Dipakai untuk mendeteksi perintah yang punya argumen, misalnya `add 3 5` → dicek apakah diawali dengan `"add "`.

**`atoi` — Ubah String Angka ke Integer**

```c
int atoi(char *str) {
    int result = 0;
    int i = 0;
    while (str[i] >= '0' && str[i] <= '9') {
        result = result * 10 + (str[i] - '0');
        i++;
    }
    return result;
}
```

Mengubah teks angka seperti `"42"` menjadi angka integer `42`. Caranya: tiap karakter angka dikurangi kode ASCII `'0'` untuk dapat nilai digitnya, lalu ditumpuk ke result.

**`intToString` — Ubah Integer ke String**

```c
void intToString(int n, char *buf) {
    ...
    while (n > 0) {
        base = n;
        quotient = 0;
        while (base >= 10) {
            base = base - 10;
            quotient = quotient + 1;
        }
        tmp[len] = base;
        len++;
        n = quotient;
    }
    ...
}
```

Kebalikan dari `atoi` — mengubah angka integer menjadi teks. Digit diekstrak satu per satu dari belakang menggunakan pengurangan berulang (karena operator `/` dan `%` tidak bisa diandalkan di lingkungan bcc bare-metal ini). Digit disimpan sementara di array `tmp` lalu dibalik urutannya ke `buf`.

---

#### Fungsi Fitur Utama

**`factorial` — Hitung Faktorial**

```c
int factorial(int n) {
    int result = 1;
    int i;
    for (i = 1; i <= n; i++) {
        result = result * i;
        if (result < 0 || result > 32767) {
            return -1;
        }
    }
    return result;
}
```

Menghitung nilai faktorial dari `n` (contoh: `5! = 1×2×3×4×5 = 120`). Ada pengecekan overflow karena di mode 16-bit, integer hanya bisa menyimpan angka dari `-32768` sampai `32767`. Kalau hasil perkalian sudah melebihi batas itu, fungsi mengembalikan `-1` sebagai tanda error, yang akan ditampilkan sebagai pesan `"know your limit little bro."`.

**`setSeason` — Ganti Warna Berdasarkan Musim**

```c
void setSeason(char *name) {
    if (strcmp(name, "winter")) {
        color = 0x0B;
        printString("winter mode");
    } else if (strcmp(name, "spring")) {
        color = 0x0A;
        printString("spring mode");
    } else if (strcmp(name, "summer")) {
        color = 0x0E;
        printString("summer mode");
    } else if (strcmp(name, "fall")) {
        color = 0x0C;
        printString("fall mode");
    } else if (strcmp(name, "radiant")) {
        color = 0x0D;
        printString("radiant mode");
    } else {
        printString("unknown season");
    }
}
```

Mengubah warna teks layar berdasarkan nama musim yang diinput. Variabel `color` adalah variabel global, jadi setelah diubah, semua teks yang dicetak berikutnya akan menggunakan warna baru tersebut.


**`printTriangle` — Cetak Segitiga**

```c
void printTriangle(int n) {
    int i, j;
    for (i = 1; i <= n; i++) {
        for (j = 0; j < i; j++) {
            printChar('x');
        }
        newline();
    }
}
```

Mencetak segitiga dari karakter `x` setinggi `n` baris. Baris ke-1 cetak 1 `x`, baris ke-2 cetak 2 `x`, dan seterusnya. Contoh output `triangle 4`:
```
x
xx
xxx
xxxx
```

---

#### Fungsi Parser Perintah

**`getWord` — Ambil Satu Kata dari Kalimat**

```c
int getWord(char *cmd, int start, char *out) {
    int i = 0;
    while (cmd[start] != ' ' && cmd[start] != '\0') {
        out[i] = cmd[start];
        i++;
        start++;
    }
    out[i] = '\0';
    return start;
}
```

Mengambil satu kata dari string `cmd` mulai dari posisi `start`, menyimpannya ke `out`. Berhenti saat menemukan spasi atau akhir string. Mengembalikan posisi setelah kata tersebut, berguna untuk mengambil kata berikutnya.

**`skipSpace` — Lewati Spasi**

```c
int skipSpace(char *cmd, int pos) {
    while (cmd[pos] == ' ') pos++;
    return pos;
}
```

Melewati karakter spasi berurutan. Dipakai bersama `getWord` untuk memisahkan argumen perintah. Misalnya perintah `add  10  5` (dengan spasi ganda) tetap bisa diparsing dengan benar.

---

#### Fungsi `main` — Inti Shell (Command Line)

```c
void main() {
    char cmd[64];
    char arg1[16];
    char arg2[16];
    int pos;
    int a, b, result;
    char resBuf[12];

    clearScreen();
    printString("Welcome to Assistant's Last Gift");
    newline();
    printString("type 'help'");
    newline();
    newline();

    while (1) {
        printString("> ");
        readString(cmd);
        newline();

        if (strcmp(cmd, "check")) {
            printString("ok");
        } else if (startsWith(cmd, "add ")) {
            ...
        } else if ...
        
        newline();
    }
}
```

Ini adalah fungsi utama kernel. Setelah layar dibersihkan dan pesan selamat datang ditampilkan, program masuk ke **loop tak terbatas** (`while(1)`) yang terus:

1. Tampilkan prompt `> ` untuk mengundang user mengetik
2. Baca input dari keyboard dengan `readString`
3. Periksa perintah apa yang diketik dengan `strcmp` / `startsWith`
4. Jalankan fungsi yang sesuai
5. Kembali ke langkah 1

---

### D. Sistem Build

#### Makefile

```makefile
prepare:
    dd if=/dev/zero of=floppy.img bs=512 count=2880

bootloader:
    nasm -f bin bootloader.asm -o bootloader.bin
    dd if=bootloader.bin of=floppy.img bs=512 count=1 conv=notrunc

kernel:
    nasm -f as86 kernel.asm -o kernel-asm.o
    bcc -ansi -c kernel.c -o kernel.o
    ld86 -o kernel.bin -d kernel-asm.o kernel.o
    dd if=kernel.bin of=floppy.img bs=512 seek=1 count=15 conv=notrunc

build: prepare bootloader kernel

run:
    bochs -q -f bochsrc.txt
```

Proses build dilakukan dalam beberapa tahap:

**1. `prepare`** — Buat file image floppy disk kosong ukuran 1.44 MB (2880 × 512 byte) menggunakan perintah `dd`. File ini nantinya akan menjadi "virtual floppy disk" yang dijalankan di emulator.

**2. `bootloader`** — Kompilasi `bootloader.asm` menjadi binary murni menggunakan `nasm -f bin`, lalu tulis hasilnya ke sektor pertama floppy image.

**3. `kernel`** — Tiga langkah sekaligus:
   - `nasm -f as86` → kompilasi `kernel.asm` ke format object as86
   - `bcc -ansi -c` → kompilasi `kernel.c` menggunakan Bruce's C Compiler (compiler khusus 16-bit)
   - `ld86 -d` → gabungkan (link) kedua object file menjadi satu file `kernel.bin`
   - Tulis `kernel.bin` ke sektor 2–16 dari floppy image

**4. `run`** — Jalankan emulator Bochs menggunakan konfigurasi dari file `bochsrc.txt`

#### bochsrc.txt (Konfigurasi Emulator Bochs)

```
megs: 32
romimage: file=/usr/share/bochs/BIOS-bochs-legacy
vgaromimage: file=/usr/share/vgabios/vgabios.bin
boot: floppy
floppya: 1_44=floppy.img, status=inserted
floppy_bootsig_check: disabled=1
log: /dev/null
mouse: enabled=0
display_library: x
```

File ini mengatur konfigurasi emulator Bochs:
- RAM virtual sebesar 32 MB
- Gunakan ROM BIOS bawaan Bochs
- Boot dari floppy disk (`floppy.img`)
- Nonaktifkan pengecekan tanda tangan boot agar lebih fleksibel
- Tampilkan output menggunakan X11 (layar grafis)

---
#### CARA NGERUNNYA DAN OUTPUTNYA 
```
make build
make run
```
maka akan muncul bochs yang masih dalam tampilan kosong
![alt text](assets/Screenshot%202026-06-04%20165741.png)

lalu ketik "c" diterminalnya
![alt text](assets/Screenshot%202026-06-04%20165805.png)

setelah mengenter c diterminal maka tampilan bochs akan berubah
![alt text](assets/Screenshot%202026-06-04%20165827.png)
akan muncul tulisan dan kita bisa mengetik di bochsnya
![alt text](assets/Screenshot%202026-06-04%20165843.png)

#### TEST CASE
1. instruksi `check`, akan memunculkan tulisan "ok"
![alt text](assets/Screenshot%202026-06-04%20170011.png)

2. fitur `add` (penjumlahan)
![alt text](assets/Screenshot%202026-06-04%20170043.png)

3. fitur `sub` (pengurangan)
![alt text](assets/Screenshot%202026-06-04%20170110.png)

4. fitur `fac` (mencari faktorial dari nilai yang diinput) serta ada batasannya yang akan tulisan peringata jika melebihi batasan
![alt text](assets/Screenshot%202026-06-04%20170257.png)

5. fitur `season` yang akan mengubah warna text di bochsnya.
Ada 5 warna (5 season)
![alt text](assets/Screenshot%202026-06-04%20170402.png)

6. fitur `clear`untuk membersihkan tampilan bochs
![alt text](assets/Screenshot%202026-06-04%20170431.png)
![alt text](assets/Screenshot%202026-06-04%20170508.png)

7. fitur `help` akan menampilkan fitur apa saja yang tersedia di bochsnya
![alt text](assets/Screenshot%202026-06-04%20170543.png)


### Kendala

Banyakk bangettt, modul tersusah karena baru kenal dengan VM, tidak terbiasa dengan VM. Pada saat menegrjakan no 2 awalnya bochs selalu ngestuck warna hitam tidak bisa diketik dan tidak bisa keluar apa apa. 