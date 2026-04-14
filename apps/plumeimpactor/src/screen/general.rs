use iced::widget::{button, column, container, image, row, text};
use iced::{Center, Color, Element, Fill, Task};
use plume_utils::Package;
use rust_i18n::t;

use crate::appearance;
use std::sync::OnceLock;

const INSTALL_IMAGE: &[u8] = include_bytes!("./general.png");
const INSTALL_IMAGE_HEIGHT: f32 = 130.0;

#[derive(Debug, Clone)]
pub enum Message {
    FilesHovered,
    FilesHoveredLeft,
    FilesDropped(Vec<std::path::PathBuf>),
    OpenFileDialog,
    FileSelected(Option<std::path::PathBuf>),
    NavigateToInstaller(plume_utils::Package),
    NavigateToUtilities,
}

#[derive(Debug, Clone, Default)]
pub struct GeneralScreen;

impl GeneralScreen {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn update(&mut self, message: Message) -> Task<Message> {
        match message {
            Message::OpenFileDialog => {
                Task::perform(
                    async {
                        rfd::AsyncFileDialog::new()
                            .add_filter(t!("ipa"), &["ipa", "tipa"])
                            .set_title(t!("select_ipa"))
                            .pick_file()
                            .await
                            .map(|file| file.path().to_path_buf())
                    },
                    Message::FileSelected,
                )
            }
            Message::FileSelected(path) => {
                if let Some(path) = path {
                    if let Ok(package) = Package::new(path) {
                        return Task::done(Message::NavigateToInstaller(package));
                    }
                }
                Task::none()
            }
            Message::FilesDropped(paths) => {
                for path in paths {
                    if let Some(ext) = path.extension() {
                        if ext == "ipa" || ext == "tipa" {
                            if let Ok(package) = Package::new(path) {
                                return Task::done(Message::NavigateToInstaller(package));
                            }
                        }
                    }
                }
                Task::none()
            }
            _ => Task::none(),
        }
    }

    pub fn view(&self) -> Element<'_, Message> {
        static INSTALL_IMAGE_HANDLE: OnceLock<image::Handle> = OnceLock::new();
        let image_handle =
            INSTALL_IMAGE_HANDLE.get_or_init(|| image::Handle::from_bytes(INSTALL_IMAGE));

        let screen_content = column![
            container(text("")).height(appearance::THEME_PADDING * 2.0),
            image(image_handle.clone()).height(INSTALL_IMAGE_HEIGHT),
            text(t!("drag_and_drop"))
                .size(appearance::THEME_FONT_SIZE + 7.0)
                .color(Color::from_rgba(1.0, 1.0, 1.0, 0.3))
        ]
        .spacing(10)
        .align_x(Center);

        column![
            container(screen_content).center(Fill).height(Fill),
            self.view_buttons()
        ]
        .into()
    }

    fn view_buttons(&self) -> Element<'_, Message> {
        container(
            row![
                button(appearance::icon_text(
                    appearance::WRENCH,
                    t!("utilities"),
                    None
                ))
                .on_press(Message::NavigateToUtilities)
                .width(Fill)
                .style(appearance::s_button),
                button(appearance::icon_text(
                    appearance::DOWNLOAD,
                    t!("import_ipa"),
                    None
                ))
                .on_press(Message::OpenFileDialog)
                .width(Fill)
                .style(appearance::s_button)
            ]
            .spacing(appearance::THEME_PADDING),
        )
        .width(Fill)
        .into()
    }
}
