# frozen_string_literal: true

RSpec.shared_examples_for 'audit events filter' do
  it 'shows only 2 days old events' do
    page.within '.content' do
      fill_in 'From', with: 4.days.ago
      fill_in 'To', with: 2.days.ago
      click_button 'Search'
    end

    expect(page).to have_content(audit_event_2.present.date)
    expect(page).not_to have_content(audit_event_1.present.date)
    expect(page).not_to have_content(audit_event_3.present.date)
  end

  it 'shows only yesterday events' do
    page.within '.content' do
      fill_in 'From', with: 2.days.ago
      click_button 'Search'
    end

    expect(page).to have_content(audit_event_3.present.date)
    expect(page).not_to have_content(audit_event_1.present.date)
    expect(page).not_to have_content(audit_event_2.present.date)
  end

  it 'shows a message if provided date is invalid' do
    page.within '.content' do
      fill_in 'From', with: '12-345-6789'
      click_button 'Search'
    end

    expect(page).to have_content('Invalid date format. Please use UTC format as YYYY-MM-DD')
  end
end
