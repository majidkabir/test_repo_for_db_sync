SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/***************************************************************************/
/* Stored Procedure: isp_RPT_ADJ_ADJDET_001                                */
/* Creation Date: 21-JAN-2022                                              */
/* Copyright: LFL                                                          */
/* Written by: Harshitha                                                   */
/*                                                                         */
/* Purpose: WMS-18811                                                      */
/*                                                                         */
/* Called By: RPT_ADJ_ADJDET_001                                           */
/*                                                                         */
/* GitLab Version: 1.0                                                     */
/*                                                                         */
/* Version: 1.0                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/* 2023-11-14 03                                                           */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/* 21-Jan-2022  WLChooi 1.0   DevOps Combine Script                        */
/***************************************************************************/
CREATE   PROC [dbo].[isp_RPT_ADJ_ADJDET_001_NXL013] (
      @c_Adjustmentkey  NVARCHAR(10)
   ,  @c_UserID         NVARCHAR(100))
 AS
BEGIN
    SET NOCOUNT ON
    SET QUOTED_IDENTIFIER OFF
    SET CONCAT_NULL_YIELDS_NULL OFF

    DECLARE @n_continue       INT
         ,  @c_errmsg         NVARCHAR(255)
         ,  @b_success        INT
         ,  @n_err            INT
         ,  @n_StartTCnt      INT

         ,  @c_SQL            NVARCHAR(MAX)
         ,  @c_Storerkey      NVARCHAR(15)


         ,  @n_UDF01IsCol     INT
         ,  @n_UDF02IsCol     INT
         ,  @n_UDF03IsCol     INT

         ,  @n_CombineSku     INT
         ,  @c_UDF01          NVARCHAR(30)
         ,  @c_UDF02          NVARCHAR(30)
         ,  @c_UDF03          NVARCHAR(30)
         ,  @c_TableName      NVARCHAR(30)

         ,  @c_Type        NVARCHAR(1) = '1'
         ,  @c_DataWindow  NVARCHAR(60) = 'RPT_ADJ_ADJDET_001'
         ,  @c_RetVal      NVARCHAR(255)

   SET @n_StartTCnt = @@TRANCOUNT

   CREATE TABLE #TMP_ADJ
      (
         Adjustmentkey     NVARCHAR(10)   NULL
      ,  StorerKey         NVARCHAR(15)   NULL
      ,  EffectiveDate     DATETIME       NULL
      ,  Sku               NVARCHAR(20)   NULL
      ,  Loc               NVARCHAR(10)   NULL
      ,  Id                NVARCHAR(18)   NULL
      ,  ReasonCode        NVARCHAR(10)   NULL
      ,  Qty               INT            NULL
      ,  Facility          NVARCHAR(5)    NULL
      ,  Remarks           NVARCHAR(200)  NULL
      ,  ADJReason_Descr   NVARCHAR(250)  NULL
      ,  UserID            NVARCHAR(20)   NULL
      )

   INSERT INTO #TMP_ADJ
      (  Adjustmentkey
      ,  StorerKey
      ,  EffectiveDate
      ,  Sku
      ,  Loc
      ,  ID
      ,  ReasonCode
      ,  Qty
      ,  Facility
      ,  Remarks
      ,  ADJReason_Descr
      ,  UserID
      )

   SELECT AH.AdjustmentKey
      ,  AH.StorerKey
      ,  AH.EffectiveDate
      ,  AD.Sku
      ,  AD.Loc
      ,  AD.ID
      ,  AD.ReasonCode
	    ,	AD.Qty
      ,  LOC.Facility
      ,  AH.Remarks

      ,Description = ( SELECT TOP 1 CODELKUP.Description
                       FROM CODELKUP (NOLOCK)
					             WHERE CODELKUP.Listname = 'ADJREASON'
							         AND CODELKUP.Code = AD.ReasonCode
                       AND (CODELKUP.Storerkey = AD.Storerkey
                            OR ISNULL(CODELKUP.Storerkey,'')='')
                       ORDER BY CODELKUP.Storerkey DESC )
      ,  @c_userid
   FROM ADJUSTMENT       AH  WITH (NOLOCK)
   JOIN ADJUSTMENTDETAIL AD  WITH (NOLOCK) ON (AH.AdjustmentKey = AD.AdjustmentKey)
   JOIN LOC              LOC WITH (NOLOCK) ON (AD.LOC = LOC.LOC)

	WHERE  AH.AdjustmentKey = @c_AdjustmentKey

   SELECT @c_Storerkey = Storerkey
   FROM ADJUSTMENT WITH (NOLOCK)
   WHERE AdjustmentKey = @c_AdjustmentKey

   SET @c_UDF01 = ''
   SET @c_UDF02 = ''
   SET @c_UDF03 = ''
   SET @n_CombineSku = 0

   SELECT @c_UDF01 = ISNULL(UDF01,'')
         ,@c_UDF02 = ISNULL(UDF02,'')
         ,@c_UDF03 = ISNULL(UDF03,'')
         ,@n_CombineSku = 1
   FROM CODELKUP WITH (NOLOCK)
   WHERE Listname = 'COMBINESKU'
   AND Code = 'CONCATENATESKU'
   AND Storerkey = @c_Storerkey

   IF @n_CombineSku = 1
   BEGIN
      SET @c_TableName = ''
      SET @c_TableName = CASE WHEN CHARINDEX('.', @c_UDF01) > 0
                              THEN SUBSTRING(@c_UDF01, 1, CHARINDEX('.', @c_UDF01)-1)
                              WHEN CHARINDEX('.', @c_UDF02) > 0
                              THEN SUBSTRING(@c_UDF02, 1, CHARINDEX('.', @c_UDF02)-1)
                              WHEN CHARINDEX('.', @c_UDF03) > 0
                              THEN SUBSTRING(@c_UDF03, 1, CHARINDEX('.', @c_UDF03)-1)
                              ELSE 'SKU'
                              END

      SET @c_UDF01 = CASE WHEN CHARINDEX('.', @c_UDF01) > 0
                          THEN SUBSTRING(@c_UDF01, CHARINDEX('.', @c_UDF01)+1, LEN(@c_UDF01) - CHARINDEX('.', @c_UDF01))
                          ELSE @c_UDF01
                          END

      SET @c_UDF02 = CASE WHEN CHARINDEX('.', @c_UDF02) > 0
                          THEN SUBSTRING(@c_UDF02, CHARINDEX('.', @c_UDF02)+1, LEN(@c_UDF02) - CHARINDEX('.', @c_UDF02))
                          ELSE @c_UDF02
                          END

      SET @c_UDF03 = CASE WHEN CHARINDEX('.', @c_UDF03) > 0
                          THEN SUBSTRING(@c_UDF03, CHARINDEX('.', @c_UDF03)+1, LEN(@c_UDF03) - CHARINDEX('.', @c_UDF03))
                          ELSE @c_UDF03
                          END

      SET @n_UDF01IsCol = 0
      SET @n_UDF02IsCol = 0
      SET @n_UDF03IsCol = 0

      SELECT @n_UDF01IsCol =  MAX(CASE WHEN COLUMN_NAME = @c_UDF01 THEN 1 ELSE 0 END)
            ,@n_UDF02IsCol =  MAX(CASE WHEN COLUMN_NAME = @c_UDF02 THEN 1 ELSE 0 END)
            ,@n_UDF03IsCol =  MAX(CASE WHEN COLUMN_NAME = @c_UDF03 THEN 1 ELSE 0 END)
      FROM   INFORMATION_SCHEMA.COLUMNS
      WHERE  TABLE_NAME = @c_TableName


      SET @c_UDF01 = CASE WHEN @n_UDF01IsCol = 1
                          THEN 'RTRIM(' + @c_TableName + '.' + @c_UDF01 + ')'
                          ELSE '''' + @c_UDF01 + ''''
                          END

      SET @c_UDF02 = CASE WHEN @n_UDF02IsCol = 1
                          THEN 'RTRIM(' + @c_TableName + '.' + @c_UDF02 + ')'
                          ELSE '''' + @c_UDF02 + ''''
                          END

      SET @c_UDF03 = CASE WHEN @n_UDF03IsCol = 1
                          THEN 'RTRIM(' + @c_TableName + '.' + @c_UDF03 + ')'
                          ELSE '''' + @c_UDF03 + ''''
                          END

      SET @c_SQL = ''
      SET @c_SQL = N' UPDATE #TMP_ADJ'
                 +  ' SET SKU = ' + @c_UDF01 + ' + ' + @c_UDF02 + ' + ' + @c_UDF03
                 +  ' FROM  #TMP_ADJ TMP '
                 +  ' JOIN ' + @c_TableName + ' WITH (NOLOCK) ON  TMP.Storerkey = SKU.Storerkey'
                 +                                          ' AND TMP.Sku = SKU.Sku'

      EXEC ( @c_SQL )
   END

   QUIT_SP:
   EXEC [dbo].[isp_GetCompanyInfo]
         @c_Storerkey  = @c_Storerkey
      ,  @c_Type       = @c_Type
      ,  @c_DataWindow = @c_DataWindow
      ,  @c_RetVal     = @c_RetVal           OUTPUT

   SELECT Adjustmentkey
      ,  StorerKey
      ,  EffectiveDate
      ,  Sku
      ,  Loc
      ,  ID
      ,  ReasonCode
      ,  Qty
      ,  Facility
      ,  Remarks
      ,  ADJReason_Descr
      ,  UserID
      ,  ISNULL(@c_Retval,'') AS Logo
   FROM #TMP_ADJ

   WHILE @@TRANCOUNT < @n_StartTCnt
      BEGIN TRAN

   /* #INCLUDE <SPTPA01_2.SQL> */
   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_success = 0
      IF @@TRANCOUNT > @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTCnt
         BEGIN
            COMMIT TRAN
         END
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_RPT_ADJ_ADJDET_001'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR
      RETURN
   END
   ELSE
   BEGIN
      SELECT @b_success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END

END

GO