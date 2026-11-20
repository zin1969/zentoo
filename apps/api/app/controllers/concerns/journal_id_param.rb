# app/controllers/concerns/journal_id_param.rb

# パスの仕訳 ID を取り出す。DB 関数の引数は INT なので、範囲外の ID は存在しない仕訳として扱う。
# ルートで数字だけに絞っているので、ここでは範囲だけを確かめる。
module JournalIdParam
  MAX_JOURNAL_ID = 2_147_483_647

  private

  def journal_id_param
    journal_id = Integer(params[:id])
    raise Journals::JournalNotFoundError unless journal_id.between?(1, MAX_JOURNAL_ID)

    journal_id
  end
end
