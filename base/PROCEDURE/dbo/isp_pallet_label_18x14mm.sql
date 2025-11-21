SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Stored Proc: isp_PALLET_LABEL_18x14mm                                */
/* Creation Date: 23-NOV-2018                                           */
/* Copyright: LF Logistics                                              */
/* Written by: CZTENG                                                   */
/*                                                                      */
/* Purpose: Select data from standard stored procedure                  */
/*          isp_INSERT_PALLET_LABEL                                     */
/*                                                                      */
/* Called By: r_dw_pallet_label_18x14                                   */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 1.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 24-AUG-2022 LZG      1.1   JSM-90463 - Extended to 10 chars (ZG01)   */
/************************************************************************/

CREATE PROC [dbo].[isp_PALLET_LABEL_18x14mm]
         @n_Qty         INT
      ,  @c_Prefix      NVARCHAR(10)          -- ZG01
      ,  @c_Title       NVARCHAR(30)
      ,  @c_StorerKey   NVARCHAR(15)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  @c_ErrMsg      NVARCHAR(255)
         ,  @b_Success     INT
         ,  @n_Err         INT

   CREATE TABLE #TMP_PALLET
      ( Title        NVARCHAR(30)
      , PalletID     NVARCHAR(10)
      , StorerKey    NVARCHAR(15)
      , [Date]       DATETIME
      , [Count]      INT
      , Qty          INT
      , udf01        NVARCHAR(30)
      , udf02        NVARCHAR(30)
      , udf03        NVARCHAR(30)
      , udf04        NVARCHAR(30)
      , udf05        NVARCHAR(30)
      )

   INSERT INTO #TMP_PALLET
   EXEC   isp_INSERT_PALLET_LABEL
             @n_Qty       = @n_Qty
           , @c_Prefix    = @c_Prefix
           , @c_Title     = @c_Title
           , @c_StorerKey = @c_StorerKey
           , @c_ErrMsg    = @c_ErrMsg  OUTPUT
           , @b_Success   = @b_Success OUTPUT
           , @n_Err       = @n_Err     OUTPUT

   SELECT Title
        , PalletID
        , StorerKey
        , [Date]
   FROM #TMP_PALLET

END

SET QUOTED_IDENTIFIER OFF

GO