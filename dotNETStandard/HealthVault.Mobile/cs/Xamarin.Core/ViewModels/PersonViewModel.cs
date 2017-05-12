﻿using Xamarin.Forms;

namespace HealthVault.Sample.Xamarin.Core.ViewModels
{
    class PersonViewModel
    {
        public ImageSource ImageSource { get; set; }
        public string FirstName { get; set; }
        public string LastName { get; set; }
        public string BirthMonth { get; set; }
        public string BirthYear { get; set; }
        public string Gender { get; set; }
        public string Weight { get; set; }
    }
}