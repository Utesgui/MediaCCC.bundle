using System;
using System.Collections.Generic;
using System.Text.Json.Serialization;

namespace Jellyfin.Plugin.MediaCCC.Api.Models
{
    /// <summary>
    /// Repräsentiert ein Event.
    /// </summary>
    public class Event
    {
        /// <summary>
        /// Gets or sets the guid.
        /// </summary>
        [JsonPropertyName("guid")]
        public string Guid { get; set; }

        /// <summary>
        /// Gets or sets the title.
        /// </summary>
        [JsonPropertyName("title")]
        public string Title { get; set; }

        /// <summary>
        /// Gets or sets the subtitle.
        /// </summary>
        [JsonPropertyName("subtitle")]
        public string Subtitle { get; set; }

        /// <summary>
        /// Gets or sets the description.
        /// </summary>
        [JsonPropertyName("description")]
        public string Description { get; set; }

        /// <summary>
        /// Gets or sets the duration in seconds.
        /// </summary>
        [JsonPropertyName("duration")]
        public int Duration { get; set; }

        /// <summary>
        /// Gets or sets the thumbnail URL.
        /// </summary>
        [JsonPropertyName("thumb_url")]
        public string ThumbUrl { get; set; }

        /// <summary>
        /// Gets or sets the poster URL.
        /// </summary>
        [JsonPropertyName("poster_url")]
        public string PosterUrl { get; set; }

        /// <summary>
        /// Gets or sets the URL.
        /// </summary>
        [JsonPropertyName("url")]
        public string Url { get; set; }

        /// <summary>
        /// Gets or sets the original language.
        /// </summary>
        [JsonPropertyName("original_language")]
        public string OriginalLanguage { get; set; }

        /// <summary>
        /// Gets or sets the date.
        /// </summary>
        [JsonPropertyName("date")]
        public DateTime Date { get; set; }

        /// <summary>
        /// Gets or sets the tags.
        /// </summary>
        [JsonPropertyName("tags")]
        public List<string> Tags { get; set; }
    }

    /// <summary>
    /// Detaillierte Informationen zu einem Event.
    /// </summary>
    public class EventDetail : Event
    {
        /// <summary>
        /// Gets or sets the recordings.
        /// </summary>
        [JsonPropertyName("recordings")]
        public List<Recording> Recordings { get; set; }

        /// <summary>
        /// Gets or sets the persons.
        /// </summary>
        [JsonPropertyName("persons")]
        public List<string> Persons { get; set; }
    }

    /// <summary>
    /// Eine Aufnahme eines Events.
    /// </summary>
    public class Recording
    {
        /// <summary>
        /// Gets or sets the size.
        /// </summary>
        [JsonPropertyName("size")]
        public long Size { get; set; }

        /// <summary>
        /// Gets or sets the length.
        /// </summary>
        [JsonPropertyName("length")]
        public int Length { get; set; }

        /// <summary>
        /// Gets or sets the mime type.
        /// </summary>
        [JsonPropertyName("mime_type")]
        public string MimeType { get; set; }

        /// <summary>
        /// Gets or sets the language.
        /// </summary>
        [JsonPropertyName("language")]
        public string Language { get; set; }

        /// <summary>
        /// Gets or sets the filename.
        /// </summary>
        [JsonPropertyName("filename")]
        public string Filename { get; set; }

        /// <summary>
        /// Gets or sets the folder.
        /// </summary>
        [JsonPropertyName("folder")]
        public string Folder { get; set; }

        /// <summary>
        /// Gets or sets the URL of the recording.
        /// </summary>
        [JsonPropertyName("recording_url")]
        public string RecordingUrl { get; set; }

        /// <summary>
        /// Gets or sets the width.
        /// </summary>
        [JsonPropertyName("width")]
        public int Width { get; set; }

        /// <summary>
        /// Gets or sets the height.
        /// </summary>
        [JsonPropertyName("height")]
        public int Height { get; set; }

        /// <summary>
        /// Gets or sets the type.
        /// </summary>
        [JsonPropertyName("type")]
        public string Type { get; set; }
    }
}
