SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger:  ispPRREC33                                                 */
/* Creation Date: 29-May-2024                                           */
/* Copyright: Maersk                                                    */
/* Written by: Shreekanth                                               */
/*                                                                      */
/* Purpose:  Calculate Shelf life to update Lottable06 & Lottable07     */
/*        for Damaged and Expired                                       */
/*                                                                      */
/*                                                                      */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/************************************************************************/

CREATE   PROC [dbo].[ispPRREC33]
(     @c_Receiptkey  NVARCHAR(10)
  ,   @c_ReceiptLineNumber  NVARCHAR(5)
  ,   @b_Success     INT           OUTPUT
  ,   @n_Err         INT           OUTPUT
  ,   @c_ErrMsg      NVARCHAR(255) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON
    SET QUOTED_IDENTIFIER OFF
    SET ANSI_NULLS OFF
    SET CONCAT_NULL_YIELDS_NULL OFF

    DECLARE
        @c_Lottable12Value      NVARCHAR(30),
        @c_Storerkey            NVARCHAR(30),
        @dt_ExpirationDate      DATETIME,
        @c_DamagedCode          NVARCHAR(30),
        @c_ExpiredCode          NVARCHAR(30)

    IF ISNULL(@c_ReceiptLineNumber,'') = ''
        BEGIN
               DECLARE CUR_RECEIPTLINES CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                    SELECT RD.ReceiptKey, RD.ReceiptLineNumber, Lottable12, StorerKey, Lottable04
                    FROM dbo.RECEIPTDETAIL RD WITH (NOLOCK)
                    WHERE RD.ReceiptKey = @c_Receiptkey
        END
    ELSE
        BEGIN
               DECLARE CUR_RECEIPTLINES CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                    SELECT RD.ReceiptKey, RD.ReceiptLineNumber, Lottable12, StorerKey, Lottable04
                    FROM dbo.RECEIPTDETAIL RD WITH (NOLOCK)
                    WHERE RD.ReceiptKey = @c_Receiptkey
                    AND RD.ReceiptLineNumber = @c_ReceiptLineNumber
        END

        OPEN CUR_RECEIPTLINES
        FETCH NEXT FROM CUR_RECEIPTLINES INTO @c_Receiptkey, @c_ReceiptLineNumber, @c_Lottable12Value, @c_Storerkey, @dt_ExpirationDate

        WHILE @@FETCH_STATUS = 0
            BEGIN
                IF EXISTS (SELECT 1
                              FROM CODELKUP WITH (NOLOCK) WHERE LISTNAME = 'ASNREASON'
                               AND Code = @c_Lottable12Value
                               AND StorerKey = @c_Storerkey)
                    BEGIN
                        SET @c_DamagedCode = ''

                        SELECT @c_DamagedCode = ISNULL(Code,'')
                            FROM CODELKUP WITH (NOLOCK)
                            WHERE storerkey = @c_Storerkey
                            AND UDF01 = 'RMPM_Damaged'
                            AND LISTNAME = 'SLCode'

                        IF ISNULL(@c_DamagedCode,'') <> ''
                        BEGIN
                            SET @n_Err = 63533;
                            SET @c_ErrMsg = 'Damaged Code is not configured for this Storer key' +@c_Storerkey;
                            SET @b_Success = 0;
                        END
                ELSE
                    BEGIN
                        BEGIN TRY
                            UPDATE RECEIPTDETAIL WITH (ROWLOCK)
                            SET [LOTTABLE07] = @c_DamagedCode, [LOTTABLE06] = '1',
                                Trafficcop = NULL
                            WHERE ReceiptKey = @c_Receiptkey AND
                                StorerKey = @c_Storerkey AND
                                ReceiptLineNumber = @c_Receiptlinenumber;
                            SET @b_Success = 1;
                        END TRY
                        BEGIN CATCH
                            SET @n_Err = 63532
                            SET @c_ErrMsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update RECEIPTDETAIL Table Failed. (ispPRREC33)'
                                       + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg),'') + ' ) '
                            SET @b_Success = 0;
                        END CATCH
                    END
                END -- Reason Code Exists
    ELSE IF DATEDIFF(DAY, @dt_ExpirationDate, GETDATE()) <= 0
    BEGIN
        SET @c_ExpiredCode = ''

        SELECT @c_ExpiredCode = ISNULL(Code,'')
            FROM CODELKUP WITH (NOLOCK)
            WHERE storerkey = @c_Storerkey
              AND UDF01 = 'RMPM_Expired' AND LISTNAME = 'SLCode'

        IF @c_ExpiredCode = ''
        BEGIN
            SET @n_Err = 63533;
            SET @c_ErrMsg = 'Expired Code is not configured for this Storer key' +@c_Storerkey;
            SET @b_Success = 0;
        END
    ELSE
        BEGIN
            BEGIN TRY
                UPDATE RECEIPTDETAIL WITH (ROWLOCK)
                SET [LOTTABLE07] = @c_ExpiredCode, [LOTTABLE06] = '1',
                Trafficcop = NULL
                WHERE ReceiptKey = @c_Receiptkey AND
                    StorerKey = @c_Storerkey AND
                    ReceiptLineNumber = @c_Receiptlinenumber;

                SET @b_Success = 1;
            END TRY
            BEGIN CATCH
                SET @n_Err = 63532
                            SET @c_ErrMsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update RECEIPTDETAIL Table Failed. (ispPRREC33)'
                                         + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg),'') + ' ) '
                            SET @b_Success = 0;
            END CATCH
        END
    END

    FETCH NEXT FROM CUR_RECEIPTLINES INTO @c_Receiptkey, @c_ReceiptLineNumber, @c_Lottable12Value, @c_Storerkey, @dt_ExpirationDate
END
CLOSE CUR_RECEIPTLINES
        DEALLOCATE CUR_RECEIPTLINES


--SELECT @c_Lottable12Value = Lottable12, @c_Storerkey = StorerKey, @dt_ExpirationDate = Lottable04
--                    FROM RECEIPTDETAIL WITH (NOLOCK)
--                    WHERE ReceiptKey = @c_Receiptkey AND
--                    ReceiptLineNumber = @c_Receiptlinenumber;



END -- End Procedure

GO