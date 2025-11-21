SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  isp_adjsumm_03                                     */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose:  Change to call SP for Customize                            */
/*                                                                      */
/* Input Parameters:  @c_Adjustmentkey  - Adjustnment Key               */
/*                 ,  @c_UserID                                         */
/*                                                                      */
/* Output Parameters:  None                                             */
/*                                                                      */
/* Return Status:  None                                                 */
/*                                                                      */
/* Usage:  Used for report dw = r_dw_adjusment_summary_03               */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_adjsumm_03] (
      @c_Adjustmentkey  NVARCHAR(10)
   ,  @c_UserID         NVARCHAR(20))
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
         ,  @c_ClkStorerKey   NVARCHAR(15)	--SOS324756

   SET @n_StartTCnt = @@TRANCOUNT

   --SOS324756 Start
   SELECT @c_Storerkey = Storerkey
   FROM ADJUSTMENT WITH (NOLOCK)
   WHERE AdjustmentKey = @c_AdjustmentKey

   IF EXISTS (SELECT 1 FROM CODELKUP WITH (NOLOCK)
				  WHERE ListName = 'ADJTYPE' AND StorerKey = @c_Storerkey)
	BEGIN
   	SET @c_ClkStorerKey = @c_Storerkey
	END
	ELSE
	BEGIN
   	SET @c_ClkStorerKey = ''
	END
   --SOS324756 End

   CREATE TABLE #TMP_ADJ
      (
         Adjustmentkey     NVARCHAR(10)   NULL
      ,  StorerKey         NVARCHAR(15)   NULL
      ,  EffectiveDate     DATETIME       NULL
      ,  Sku               NVARCHAR(20)   NULL
      ,  Loc               NVARCHAR(10)   NULL
      ,  Lot               NVARCHAR(10)   NULL
      ,  AdjustmentType    NVARCHAR(3)    NULL
      ,  Id                NVARCHAR(18)   NULL
      ,  ReasonCode        NVARCHAR(10)   NULL
      ,  Qty               INT            NULL
      ,  SkuDescr          NVARCHAR(60)   NULL
      ,  Facility          NVARCHAR(5)    NULL
      ,  ADJTypeDescr      NVARCHAR(250)  NULL
      ,  UserID            NVARCHAR(20)   NULL
      ,  AFacility         NVARCHAR(5)    NULL
      ,  CustomerRefNo     NVARCHAR(10)   NULL
      ,  DocType           NVARCHAR(5)   NULL
      ,  Remarks           NVARCHAR(200)   NULL
      ,  Reason            NVARCHAR(100)   NULL
      ,  PUOM3             NVARCHAR(10)   NULL
      )

   INSERT INTO #TMP_ADJ
      (  Adjustmentkey
      ,  StorerKey
      ,  EffectiveDate
      ,  Sku
      ,  Loc
      ,  Lot
      ,  AdjustmentType
      ,  Id
      ,  ReasonCode
      ,  Qty
      ,  SkuDescr
      ,  Facility
      ,  ADJTypeDescr
      ,  UserID
      ,  AFacility         
      ,  CustomerRefNo     
      ,  DocType          
      ,  Remarks             
      ,  Reason            
      ,  PUOM3             
      )

   SELECT AH.AdjustmentKey
      ,  AH.StorerKey
      ,  AH.EffectiveDate
      ,  AD.Sku
      ,  AD.Loc
      ,  AD.Lot
      ,  AH.AdjustmentType
      ,  AD.Id
      ,  AD.ReasonCode
      ,  AD.Qty
      ,  SKU.Descr
      ,  LOC.Facility
      ,  CL.Description
      ,  @c_userid
      , AH.Facility
      , AH.CustomerRefNo
      , AH.DocType
      , AH.Remarks
      , CL1.[Description]
      , P.PackUOM3
   FROM ADJUSTMENT       AH  WITH (NOLOCK)
   JOIN ADJUSTMENTDETAIL AD  WITH (NOLOCK) ON (AH.AdjustmentKey = AD.AdjustmentKey)
   JOIN LOC              LOC WITH (NOLOCK) ON (AD.LOC = LOC.LOC)
   JOIN SKU              SKU WITH (NOLOCK) ON (AD.Storerkey = SKU.Storerkey)
                                         AND(AD.SKU = SKU.SKU)
   LEFT JOIN CODELKUP         CL  WITH (NOLOCK) ON (CL.Listname = 'ADJTYPE')
                                         AND(AH.AdjustmentType = CL.Code )
                                         AND(CL.StorerKey = @c_ClkStorerKey)	--SOS324756
   LEFT JOIN CODELKUP CL1 WITH (NOLOCK) ON CL1.listname='ADJREASON' AND(CL1.StorerKey = AH.StorerKey)
                                        AND CL1.Code=AD.ReasonCode
   JOIN PACK P WITH (NOLOCK) ON P.PackKey=SKU.PACKKey                                                                             
   WHERE  AH.AdjustmentKey = @c_AdjustmentKey

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
   SELECT Adjustmentkey
      ,  StorerKey
      ,  EffectiveDate
      ,  Sku
      ,  Loc
      ,  Lot
      ,  AdjustmentType
      ,  Id
      ,  ReasonCode
      ,  Qty
      ,  SkuDescr
      ,  Facility
      ,  ADJTypeDescr
      ,  UserID
      ,  AFacility         
      ,  CustomerRefNo      
      ,  DocType          
      ,  Remarks               
      ,  Reason            
      ,  PUOM3     
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_adjsumm_03'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
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