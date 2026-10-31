/// Model bài hát thật trong SupaChat
class MusicTrack {
  final String id;
  final String title;
  final String artist;
  final String audioUrl;
  final String coverUrl;
  final String duration;

  const MusicTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.audioUrl,
    required this.coverUrl,
    required this.duration,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'artist': artist,
    'audioUrl': audioUrl,
    'coverUrl': coverUrl,
    'duration': duration,
  };

  factory MusicTrack.fromMap(Map<String, dynamic> map) => MusicTrack(
    id: map['id'] ?? '',
    title: map['title'] ?? '',
    artist: map['artist'] ?? '',
    audioUrl: map['audioUrl'] ?? '',
    coverUrl: map['coverUrl'] ?? '',
    duration: map['duration'] ?? '',
  );
}

/// Danh sách 20 bài hát V-POP THẬT 100%, phát mượt mà trực tuyến trên Web & Mobile
class MusicTrackLibrary {
  static const List<MusicTrack> tracks = [
    MusicTrack(
      id: 'vpop_01',
      title: 'Chạy Ngay Đi',
      artist: 'Sơn Tùng M-TP',
      audioUrl: 'https://archive.org/download/sontungmtp-chayngaydi/S%C6%A1n%20T%C3%B9ng%20M-TP%20%E2%80%93%20Ch%E1%BA%A1y%20Ngay%20%C4%90i.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=300',
      duration: '04:08',
    ),
    MusicTrack(
      id: 'vpop_02',
      title: 'Nếu Lúc Đó',
      artist: 'tlinh & 2pillz',
      audioUrl: 'https://archive.org/download/neu-luc-do/a%CC%81i/a%CC%81i.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=300',
      duration: '04:21',
    ),
    MusicTrack(
      id: 'vpop_03',
      title: 'Vì Yêu Cứ Đâm Đầu',
      artist: 'MIN ft. Đen Vâu & JustaTee',
      audioUrl: 'https://archive.org/download/vi-yeu-cu-dam-dau-min-justa-tee-ft-den-vau-r-b-remix/V%C3%AC%20Y%C3%AAu%20C%E1%BB%A9%20%C4%90%C3%A2m%20%C4%90%E1%BA%A7u%20-%20Min%2C%20JustaTee%20ft%20%C4%90en%20V%C3%A2u%20%28R%26B%20Remix%29.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=300',
      duration: '03:45',
    ),
    MusicTrack(
      id: 'vpop_04',
      title: 'Em Đừng Khóc',
      artist: 'Chillies',
      audioUrl: 'https://archive.org/download/em-dung-khoc-chillies_202211/Em%20%C4%90%E1%BB%ABng%20Kh%C3%B3c%20-%20Chillies.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1459749411175-04bf5292ceea?w=300',
      duration: '04:14',
    ),
    MusicTrack(
      id: 'vpop_05',
      title: 'Bình Yên Những Phút Giây',
      artist: 'Sơn Tùng M-TP',
      audioUrl: 'https://archive.org/download/binh-yen-nhung-phut-giay-son-tung-m-tp/Binh%20Yen%20Nhung%20Phut%20Giay%20-%20Son%20Tung%20M%20TP.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=300',
      duration: '03:52',
    ),
    MusicTrack(
      id: 'vpop_06',
      title: 'Khóc',
      artist: 'Đông Nhi',
      audioUrl: 'https://archive.org/download/1.-khoc-dong-nhi/01.%20Kh%C3%B3c%20-%20%C4%90%C3%B4ng%20Nhi.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1518609878373-06d740f60d8b?w=300',
      duration: '04:10',
    ),
    MusicTrack(
      id: 'vpop_07',
      title: 'Cô Gái Trung Hoa',
      artist: 'Lương Bích Hữu',
      audioUrl: 'https://archive.org/download/06.-goi-ten-toi-nhe-ban-than-hoi/01.%20C%C3%B4%20g%C3%A1i%20Trung%20Hoa%20%28wo%20ai%20ni%29.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?w=300',
      duration: '03:30',
    ),
    MusicTrack(
      id: 'vpop_08',
      title: 'Chúng Ta Không Thuộc Về Nhau',
      artist: 'Sơn Tùng M-TP',
      audioUrl: 'https://archive.org/download/chung-ta-khong-thuoc-ve-nhau-son-tung-m-tp-manh-me-len-v.-a-playlist-nhac-cua-tui_202105/Ch%C3%BAng%20Ta%20Kh%C3%B4ng%20Thu%E1%BB%99c%20V%E1%BB%81%20Nhau%20-%20S%C6%A1n%20T%C3%B9ng%20M-TP%20-%20M%E1%BA%A1nh%20M%E1%BA%BD%20L%C3%AAn%20-%20V.A%20-%20Playlist%20NhacCuaTui.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=300',
      duration: '03:53',
    ),
    MusicTrack(
      id: 'vpop_09',
      title: 'Gửi Anh Xa Nhớ',
      artist: 'Bích Phương',
      audioUrl: 'https://archive.org/download/gui-anh-xa-nho-bich-phuong-thuong-em-vi-do-la-em-v.-a-playlist-nhac-cua-tui/G%E1%BB%ADi%20Anh%20Xa%20Nh%E1%BB%9B%20-%20B%C3%ADch%20Ph%C6%B0%C6%A1ng%20-%20Th%C6%B0%C6%A1ng%20Em%20V%C3%AC%20%C4%90%C3%B3%20L%C3%A0%20Em%20-%20V.A%20-%20Playlist%20NhacCuaTui.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=300',
      duration: '03:40',
    ),
    MusicTrack(
      id: 'vpop_10',
      title: 'Xe Đạp',
      artist: 'Thùy Chi & M4U',
      audioUrl: 'https://archive.org/download/xe-dap-m-4-u-thuy-chi-nhung-bai-hat-hay-nhat-cua-thuy-chi-thuy-chi-playlist-nhac-cua-tui/Xe%20%C4%90%E1%BA%A1p%20-%20M4U%2C%20Th%C3%B9y%20Chi%20-%20Nh%E1%BB%AFng%20B%C3%A0i%20H%C3%A1t%20Hay%20Nh%E1%BA%A5t%20C%E1%BB%A7a%20Th%C3%B9y%20Chi%20-%20Th%C3%B9y%20Chi%20-%20Playlist%20NhacCuaTui.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1459749411175-04bf5292ceea?w=300',
      duration: '04:30',
    ),
    MusicTrack(
      id: 'vpop_11',
      title: 'Luôn Yêu Đời',
      artist: 'Đen Vâu ft. Cheng',
      audioUrl: 'https://archive.org/download/luon-yeu-doi-den-cheng-dac-sac-nhat-v.-a-playlist-nhac-cua-tui/Lu%C3%B4n%20y%C3%AAu%20%C4%91%E1%BB%9Di%20-%20%C4%90en%2C%20Cheng%20-%20%C4%90%E1%BA%B7c%20S%E1%BA%AFc%20Nh%E1%BA%A5t%20-%20V.A%20-%20Playlist%20NhacCuaTui.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=300',
      duration: '03:35',
    ),
    MusicTrack(
      id: 'vpop_12',
      title: 'Có Em Mỗi Bước Anh Đi',
      artist: 'Da LAB',
      audioUrl: 'https://archive.org/download/co-em-moi-buoc-anh-di-da-lab-nhac-tre-tuyen-chon-v.-a-playlist-nhac-cua-tui/C%C3%B3%20Em%20M%E1%BB%97i%20B%C6%B0%E1%BB%9Bc%20Anh%20%C4%90i%20-%20Da%20LAB%20-%20Nh%E1%BA%A1c%20Tr%E1%BA%BB%20Tuy%E1%BB%83n%20Ch%E1%BB%8Dn%20-%20V.A%20-%20Playlist%20NhacCuaTui.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?w=300',
      duration: '03:50',
    ),
    MusicTrack(
      id: 'vpop_13',
      title: 'Mặt Trời Khóc',
      artist: 'Emcee L ft. Orange',
      audioUrl: 'https://archive.org/download/mat-troi-khoc-emcee-l-orange-dac-sac-nhat-v.-a-playlist-nhac-cua-tui_202307/M%E1%BA%B7t%20Tr%E1%BB%9Di%20Kh%C3%B3c%20-%20Emcee%20L%2C%20Orange%20-%20%C4%90%E1%BA%B7c%20S%E1%BA%AFc%20Nh%E1%BA%A5t%20-%20V.A%20-%20Playlist%20NhacCuaTui.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=300',
      duration: '03:48',
    ),
    MusicTrack(
      id: 'vpop_14',
      title: 'Nắng Đã Làm Má Em Thêm Hồng',
      artist: 'Charles',
      audioUrl: 'https://archive.org/download/nang-da-lam-ma-em-them-hong-charles-anh-van-doi-mai-thoi-v.-a-playlist-nhac-cua-tui/N%E1%BA%AFng%20%C4%90%C3%A3%20L%C3%A0m%20M%C3%A1%20Em%20Th%C3%AAm%20H%E1%BB%93ng%20-%20Charles%20-%20Anh%20V%E1%BA%ABn%20%C4%90%E1%BB%A3i%20M%C3%A3i%20Th%C3%B4i%20-%20V.A%20-%20Playlist%20NhacCuaTui.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=300',
      duration: '03:22',
    ),
    MusicTrack(
      id: 'vpop_15',
      title: 'Có Em Đời Bỗng Vui',
      artist: 'Chillies',
      audioUrl: 'https://archive.org/download/co-em-doi-bong-vui-chillies-30-roi-cuoi-thoi-v.-a-playlist-nhac-cua-tui/C%C3%B3%20Em%20%C4%90%E1%BB%9Di%20B%E1%BB%97ng%20Vui%20-%20Chillies%20-%2030%20R%E1%BB%93i%20C%C6%B0%E1%BB%9Bi%20Th%C3%B4i%21%20-%20V.A%20-%20Playlist%20NhacCuaTui.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1459749411175-04bf5292ceea?w=300',
      duration: '03:55',
    ),
    MusicTrack(
      id: 'vpop_16',
      title: 'Giấc Mơ Khác',
      artist: 'Chillies',
      audioUrl: 'https://archive.org/download/giac-mo-khac-chillies-thien-ha-nghe-nhieu-v.-a-playlist-nhac-cua-tui/Gi%E1%BA%A5c%20M%C6%A1%20Kh%C3%A1c%20-%20Chillies%20-%20Thi%C3%AAn%20H%E1%BA%A1%20Nghe%20Nhi%E1%BB%81u%20-%20V.A%20-%20Playlist%20NhacCuaTui.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=300',
      duration: '03:40',
    ),
    MusicTrack(
      id: 'vpop_17',
      title: 'Một Cái Tên',
      artist: 'Chillies ft. Orange',
      audioUrl: 'https://archive.org/download/mot-cai-ten-chillies-orange-nhac-viet-hot-thang-06-2021-v.-a-playlist-nhac-cua-tui_202107/M%E1%BB%99t%20C%C3%A1i%20T%C3%AAn%20-%20Chillies%2C%20Orange%20-%20Nh%E1%BA%A1c%20Vi%E1%BB%87t%20Hot%20Th%C3%A1ng%2006_2021%20-%20V.A%20-%20Playlist%20NhacCuaTui.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=300',
      duration: '04:02',
    ),
    MusicTrack(
      id: 'vpop_18',
      title: 'Cơn Mưa Xa Dần',
      artist: 'Sơn Tùng M-TP',
      audioUrl: 'https://archive.org/download/con-mua-xa-dan-son-tung-m-tp-nhac-viet-hot-thang-11-2022-v.-a-playlist-nhac-cua-tui/C%C6%A1n%20M%C6%B0a%20Xa%20D%E1%BA%A7n%20-%20S%C6%A1n%20T%C3%B9ng%20M-TP%20-%20Nh%E1%BA%A1c%20Vi%E1%BB%87t%20Hot%20Th%C3%A1ng%2011_2022%20-%20V.A%20-%20Playlist%20NhacCuaTui.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1518609878373-06d740f60d8b?w=300',
      duration: '03:15',
    ),
    MusicTrack(
      id: 'vpop_19',
      title: 'Bên Em Là Hạnh Phúc',
      artist: 'Ken Quách',
      audioUrl: 'https://archive.org/download/album-ken-quach-mua-nang-tinh-doi/B%C3%AAn%20Em%20L%C3%A0%20H%E1%BA%A1nh%20Ph%C3%BAc.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?w=300',
      duration: '03:42',
    ),
    MusicTrack(
      id: 'vpop_20',
      title: 'Buông Đôi Tay Nhau Ra',
      artist: 'Sơn Tùng M-TP',
      audioUrl: 'https://archive.org/download/buo-ng-do-i-tay-nhau-ra-son-tung-m-tp-2020s-version/BU%C3%94NG%20%C4%90%C3%94I%20TAY%20NHAU%20RA%20-%20S%C6%A1n%20T%C3%B9ng%20M-TP%20%282020%27s%20Version%29.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=300',
      duration: '03:47',
    ),
  ];
}
