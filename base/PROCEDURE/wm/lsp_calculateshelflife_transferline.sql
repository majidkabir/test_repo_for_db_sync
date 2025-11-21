SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/
/* Stored Procedure: lsp_CalculateShelfLife_TransferLine                                 */
/* Creation Date: 2022-09-27                                             */
/* Copyright: Maersk                                                        */
/* Written by: SBA757                                                    */
/*                                                                       */
/* Purpose: UWP-22021 - Calculate shelf life for transfer line           */
/*                                                                       */
/* Called By:                                                            */
/*                                                                       */
/*                                                                       */
/* Version: 1.0                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date        Author   Ver   Purposes                                   */
/* 2022-09-27  SBA757   1.0   Calculate shelf life for transfer line     */
/*************************************************************************/
CREATE   PROCEDURE [WM].[lsp_CalculateShelfLife_TransferLine]
   @c_TransferKey          NVARCHAR(4000)= '',
   @c_TransferLineNumber   NVARCHAR(MAX)= '' ,
   @c_shelfLife            NVARCHAR(MAX)= ''  OUTPUT,
   @b_Success              INT          = 1   OUTPUT,
   @n_Err                  INT          = 0   OUTPUT,
   @c_ErrMsg               NVARCHAR(255)= ''  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_StorerKey          NVARCHAR(100) = ''
         , @c_SKU                NVARCHAR(100) = ''
         , @dt_Lottable04        DATETIME
         , @n_Continue           INT           = 1
         , @dt_Lottable13        DATETIME
         , @c_ShelfLifeFnc       NVARCHAR(100) = ''
         , @c_ConfigKey          NVARCHAR(20)  = 'ShelfLifeCalcFnc'

   SET @b_Success = 1
   SET @c_ErrMsg = ''
   SET @n_Err = 0


   BEGIN TRY
      SELECT
         @c_StorerKey = ToStorerKey,
         @c_SKU = ToSku,
         @dt_Lottable04 = tolottable04,
         @dt_Lottable13 = tolottable13
      FROM TRANSFERDETAIL WITH (NOLOCK)
      WHERE
         TransferKey = @c_TransferKey AND
         TransferLineNumber = @c_TransferLineNumber

      SELECT @c_ShelfLifeFnc = SValue
      FROM StorerConfig WITH (NOLOCK)
      WHERE ConfigKey = @c_ConfigKey
         AND StorerKey = @c_StorerKey

      IF @dt_Lottable04 IS NOT NULL
         BEGIN
            IF @c_ShelfLifeFnc = 'fnc_CalcShelfLifeBUL'
               SELECT @c_shelfLife =  dbo.fnc_CalcShelfLifeBUL(@c_StorerKey, @c_SKU, @dt_Lottable04)
            ELSE IF @c_ShelfLifeFnc = 'fnc_CalcShelfLifeBUD'
               SELECT @c_shelfLife =  dbo.fnc_CalcShelfLifeBUD(@c_StorerKey, @c_SKU, @dt_Lottable04, @dt_Lottable13)
         END
   END TRY   
   BEGIN CATCH
      SET @n_Continue = 3
      SET @c_ErrMsg = ERROR_MESSAGE()
      GOTO EXIT_SP
   END CATCH
   EXIT_SP:
      IF @n_Continue=3  -- Error Occured - Process And Return
         BEGIN
            SET @b_Success = 0
            EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_CalculateShelfLife_TransferLine'
         END
END  

GO