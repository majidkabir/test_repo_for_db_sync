SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  isp_Transfer_Ticket_06                             */
/* Creation Date:01-JUNE-2021                                           */
/* Copyright: IDS                                                       */
/* Written by: CHONGCS                                                  */
/*                                                                      */
/* Purpose: WMS-17100 [MY] IDSMED -Transfer Ticket Enhancement          */
/*                                                                      */
/* Input Parameters:  @c_TransferKey  - Transfer Key                    */
/*                                                                      */
/* Output Parameters:  None                                             */
/*                                                                      */
/* Return Status:  None                                                 */
/*                                                                      */
/* Usage:  Used for report dw = r_dw_transfer_ticket_06                 */
/*         Copy from r_dw_transfer_ticket                               */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.4                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver.  Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_Transfer_Ticket_06] (@c_TransferKey NVARCHAR(10))
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
         ,  @c_FromStorerkey  NVARCHAR(15)
         ,  @c_ToStorerkey    NVARCHAR(15)

         ,  @n_UDF01IsCol     INT
         ,  @n_UDF02IsCol     INT
         ,  @n_UDF03IsCol     INT

         ,  @n_CombineSku     INT
         ,  @c_UDF01          NVARCHAR(30)
         ,  @c_UDF02          NVARCHAR(30)
         ,  @c_UDF03          NVARCHAR(30)
         ,  @c_TableName      NVARCHAR(30)
         ,  @c_ClkStorerKey   NVARCHAR(15)   --SOS329051
         ,  @b_ClkStorerKey   NVARCHAR(15)   --SOS329051

         ,  @n_ShowAlllla     INT            --(Wan01)

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_ShowAlllla = 0
   --SOS329051 Start
   SELECT @c_ToStorerkey = ToStorerKey
   FROM TRANSFER WITH (NOLOCK)
   WHERE TransferKey = @c_TransferKey

   IF EXISTS (SELECT 1 FROM CODELKUP WITH (NOLOCK)
              WHERE ListName = 'TRANTYPE' AND StorerKey = @c_ToStorerkey)
   BEGIN
      SET @c_ClkStorerKey = @c_ToStorerkey
   END
   ELSE
   BEGIN
      SET @c_ClkStorerKey = ''
   END

   IF EXISTS (SELECT 1 FROM CODELKUP WITH (NOLOCK)
              WHERE ListName = 'TRNReason' AND StorerKey = @c_ToStorerkey)
   BEGIN
      SET @b_ClkStorerKey = @c_ToStorerkey
   END
   ELSE
   BEGIN
      SET @b_ClkStorerKey = ''
   END
   --SOS329051 End

   CREATE TABLE #TMP_TRFTICKET
      (
         Transferkey       NVARCHAR(10)   NULL
      ,  CustomerRefNo     NVARCHAR(10)   NULL
      ,  ReasonCode        NVARCHAR(10)   NULL
      ,  AddDate           DATETIME       NULL
      ,  FromStorerKey     NVARCHAR(15)   NULL
      ,  ToStorerKey       NVARCHAR(15)   NULL
      ,  FromSku           NVARCHAR(20)   NULL
      ,  FromLoc           NVARCHAR(10)   NULL
      ,  FromLot           NVARCHAR(10)   NULL
      ,  FromId            NVARCHAR(18)   NULL
      ,  FromUOM           NVARCHAR(10)   NULL
      ,  FromQty           INT            NULL
      ,  LOTTABLE01        NVARCHAR(18)   NULL
      ,  LOTTABLE02        NVARCHAR(18)   NULL
      ,  LOTTABLE03        NVARCHAR(18)   NULL
      ,  LOTTABLE04        DATETIME       NULL
      ,  LOTTABLE05        DATETIME       NULL
      ,  ToSku             NVARCHAR(20)   NULL
      ,  ToLoc             NVARCHAR(10)   NULL
      ,  ToLot             NVARCHAR(10)   NULL
      ,  ToId              NVARCHAR(18)   NULL
      ,  ToUOM             NVARCHAR(10)   NULL
      ,  ToQty             INT            NULL
      ,  tolottable01      NVARCHAR(18)   NULL
      ,  tolottable02      NVARCHAR(18)   NULL
      ,  tolottable03      NVARCHAR(18)   NULL
      ,  tolottable04      DATETIME       NULL
      ,  tolottable05      DATETIME       NULL
      ,  Type_Desc         NVARCHAR(60)   NULL
      ,  FromCompany       NVARCHAR(45)   NULL
      ,  ToCompany         NVARCHAR(45)   NULL
      ,  fromcasecnt       FLOAT          NULL
      ,  tocasecnt         FLOAT          NULL
      ,  fromuom1          NVARCHAR(10)   NULL
      ,  touom1            NVARCHAR(10)   NULL
      ,  fromuom3          NVARCHAR(10)   NULL
      ,  touom3            NVARCHAR(10)   NULL
      ,  Username          NVARCHAR(30)   NULL
      ,  Reason_Desc       NVARCHAR(60)   NULL
      ,  Facility          NVARCHAR(5)    NULL
      ,  ToFacility        NVARCHAR(5)    NULL
      ,  Lottable06        NVARCHAR(30)   NULL
      ,  Lottable07        NVARCHAR(30)   NULL
      ,  Lottable08        NVARCHAR(30)   NULL
      ,  Lottable09        NVARCHAR(30)   NULL
      ,  Lottable10        NVARCHAR(30)   NULL
      ,  Lottable11        NVARCHAR(30)   NULL
      ,  Lottable12        NVARCHAR(30)   NULL
      ,  Lottable13        DATETIME       NULL
      ,  Lottable14        DATETIME       NULL
      ,  Lottable15        DATETIME       NULL
      ,  ToLottable06      NVARCHAR(30)   NULL
      ,  ToLottable07      NVARCHAR(30)   NULL
      ,  ToLottable08      NVARCHAR(30)   NULL
      ,  ToLottable09      NVARCHAR(30)   NULL
      ,  ToLottable10      NVARCHAR(30)   NULL
      ,  ToLottable11      NVARCHAR(30)   NULL
      ,  ToLottable12      NVARCHAR(30)   NULL
      ,  ToLottable13      DATETIME       NULL
      ,  ToLottable14      DATETIME       NULL
      ,  ToLottable15      DATETIME       NULL
      )

   INSERT INTO #TMP_TRFTICKET
      (  Transferkey
      ,  CustomerRefNo
      ,  ReasonCode
      ,  AddDate
      ,  FromStorerKey
      ,  ToStorerKey
      ,  FromSku
      ,  FromLoc
      ,  FromLot
      ,  FromId
      ,  FromUOM
      ,  FromQty
      ,  LOTTABLE01
      ,  LOTTABLE02
      ,  LOTTABLE03
      ,  LOTTABLE04
      ,  LOTTABLE05
      ,  Lottable06      
      ,  Lottable07      
      ,  Lottable08      
      ,  Lottable09      
      ,  Lottable10     
      ,  Lottable11      
      ,  Lottable12      
      ,  Lottable13      
      ,  Lottable14      
      ,  Lottable15    
      ,  ToSku
      ,  ToLoc
      ,  ToLot
      ,  ToId
      ,  ToUOM
      ,  ToQty
      ,  tolottable01
      ,  tolottable02
      ,  tolottable03
      ,  tolottable04
      ,  tolottable05
      ,  ToLottable06      
      ,  ToLottable07      
      ,  ToLottable08      
      ,  ToLottable09      
      ,  ToLottable10      
      ,  ToLottable11      
      ,  ToLottable12      
      ,  ToLottable13      
      ,  ToLottable14      
      ,  ToLottable15
      ,  Type_Desc
      ,  FromCompany
      ,  ToCompany
      ,  fromcasecnt
      ,  tocasecnt
      ,  fromuom1
      ,  touom1
      ,  fromuom3
      ,  touom3
      ,  Username
      ,  Reason_Desc
      ,  Facility
      ,  ToFacility
      )

   SELECT TRANSFER.TransferKey,
      TRANSFER.CustomerRefNo,
      TRANSFER.ReasonCode,
      TRANSFER.AddDate,
      TRANSFER.FromStorerKey,
      TRANSFER.ToStorerKey,
      TRANSFERDETAIL.FromSku,
      TRANSFERDETAIL.FromLoc,
      TRANSFERDETAIL.FromLot,
      TRANSFERDETAIL.FromId,
      TRANSFERDETAIL.FromUOM,
      SUM(TRANSFERDETAIL.FromQty) AS FromQty,            
      TRANSFERDETAIL.LOTTABLE01,
      TRANSFERDETAIL.LOTTABLE02,
      TRANSFERDETAIL.LOTTABLE03,
      TRANSFERDETAIL.LOTTABLE04,
      TRANSFERDETAIL.LOTTABLE05,
      --(Wan01) - START
      TRANSFERDETAIL.Lottable06,        
      TRANSFERDETAIL.Lottable07,        
      TRANSFERDETAIL.Lottable08,        
      TRANSFERDETAIL.Lottable09,        
      TRANSFERDETAIL.Lottable10,        
      TRANSFERDETAIL.Lottable11,        
      TRANSFERDETAIL.Lottable12,        
      TRANSFERDETAIL.Lottable13,        
      TRANSFERDETAIL.Lottable14,        
      TRANSFERDETAIL.Lottable15, 
      --(Wan01) - END
      TRANSFERDETAIL.ToSku,
      TRANSFERDETAIL.ToLoc,
      TRANSFERDETAIL.ToLot,
      TRANSFERDETAIL.ToId,
      TRANSFERDETAIL.ToUOM,
      SUM(TRANSFERDETAIL.ToQty) AS ToQty,                
      TRANSFERDETAIL.tolottable01,
      TRANSFERDETAIL.tolottable02,
      TRANSFERDETAIL.tolottable03,
      TRANSFERDETAIL.tolottable04,
      TRANSFERDETAIL.tolottable05,
      --(Wan01) - START
      TRANSFERDETAIL.ToLottable06,      
      TRANSFERDETAIL.ToLottable07,      
      TRANSFERDETAIL.ToLottable08,      
      TRANSFERDETAIL.ToLottable09,      
      TRANSFERDETAIL.ToLottable10,      
      TRANSFERDETAIL.ToLottable11,      
      TRANSFERDETAIL.ToLottable12,      
      TRANSFERDETAIL.ToLottable13,      
      TRANSFERDETAIL.ToLottable14,      
      TRANSFERDETAIL.ToLottable15, 
      --(Wan01) - END     
      MIN(CODELKUP.Description) AS Desr_a, 
      FromCompany = STORER_a.Company,
      ToCompany = STORER_b.Company,
      fromcasecnt = PACK_a.casecnt,
      tocasecnt = PACK_b.casecnt,
      fromuom1 = RTRIM(PACK_a.Packuom1),     
      touom1 = RTRIM(PACK_b.Packuom1),       
      fromuom3 = RTRIM(PACK_a.Packuom3),     
      touom3 = RTRIM(PACK_b.Packuom3),       
      user_name = user_name(),
      MIN(CODELKUP_b.Description) AS Desr_b, 
      TRANSFER.Facility,
      TRANSFER.ToFacility
   FROM TRANSFER             WITH (NOLOCK)
   JOIN TRANSFERDETAIL       WITH (NOLOCK) ON ( TRANSFER.TransferKey = TRANSFERDETAIL.TransferKey )
   JOIN CODELKUP             WITH (NOLOCK) ON ( CODELKUP.Listname = 'TRANTYPE' )
                                         AND( TRANSFER.Type = CODELKUP.Code )
                                         AND( CODELKUP.StorerKey = @c_ClkStorerKey)    
   --WL01 Start
   --JOIN CODELKUP CODELKUP_b  WITH (NOLOCK) ON ( CODELKUP_b.Listname = 'TRNReason' )
   --                                      AND( TRANSFER.ReasonCode = CODELKUP_b.Code )
   --                                      AND( CODELKUP_b.StorerKey = @b_ClkStorerKey)   --SOS329051
   CROSS APPLY (SELECT TOP 1 C.[Description] FROM CODELKUP AS C WHERE C.STORERKEY = @b_ClkStorerKey 
                AND C.Listname = 'TRNREASON'
                AND TRANSFER.ReasonCode = C.Code
                ORDER BY CASE WHEN TRANSFER.Type = LEFT(C.Code2, 3) THEN 1 ELSE 2 END) AS CODELKUP_b
   --WL01 End
   JOIN STORER STORER_a      WITH (NOLOCK) ON ( TRANSFER.FromStorerKey = STORER_a.StorerKey )
   JOIN STORER STORER_b      WITH (NOLOCK) ON ( TRANSFER.ToStorerKey = STORER_b.StorerKey )
   JOIN  PACK PACK_a          WITH (NOLOCK) ON ( TRANSFERDETAIL.FromPackkey = Pack_a.Packkey )
   JOIN  PACK Pack_b          WITH (NOLOCK) ON ( TRANSFERDETAIL.ToPackkey = Pack_b.Packkey )
   WHERE ( TRANSFERDETAIL.TransferKey = @c_Transferkey )
   GROUP BY TRANSFER.TransferKey, --ang01
   TRANSFER.CustomerRefNo,
   TRANSFER.ReasonCode,
   TRANSFER.AddDate,
   TRANSFER.FromStorerKey,
   TRANSFER.ToStorerKey,
   TRANSFERDETAIL.FromSku,
   TRANSFERDETAIL.FromLoc,
   TRANSFERDETAIL.FromLot,
   TRANSFERDETAIL.FromId,
   TRANSFERDETAIL.FromUOM,
   --TRANSFERDETAIL.FromQty,                    -- ZG01
   TRANSFERDETAIL.LOTTABLE01,
   TRANSFERDETAIL.LOTTABLE02,
   TRANSFERDETAIL.LOTTABLE03,
   TRANSFERDETAIL.LOTTABLE04,
   TRANSFERDETAIL.LOTTABLE05,
   --(Wan01) - START
   TRANSFERDETAIL.Lottable06,        
   TRANSFERDETAIL.Lottable07,        
   TRANSFERDETAIL.Lottable08,        
   TRANSFERDETAIL.Lottable09,        
   TRANSFERDETAIL.Lottable10,        
   TRANSFERDETAIL.Lottable11,        
   TRANSFERDETAIL.Lottable12,        
   TRANSFERDETAIL.Lottable13,        
   TRANSFERDETAIL.Lottable14,        
   TRANSFERDETAIL.Lottable15,
   --(Wan01) - END 
   TRANSFERDETAIL.ToSku,
   TRANSFERDETAIL.ToLoc,
   TRANSFERDETAIL.ToLot,
   TRANSFERDETAIL.ToId,
   TRANSFERDETAIL.ToUOM,
   --TRANSFERDETAIL.ToQty,                -- ZG01
   TRANSFERDETAIL.tolottable01,
   TRANSFERDETAIL.tolottable02,
   TRANSFERDETAIL.tolottable03,
   TRANSFERDETAIL.tolottable04,
   TRANSFERDETAIL.tolottable05,
   --(Wan01) - START
   TRANSFERDETAIL.ToLottable06,      
   TRANSFERDETAIL.ToLottable07,      
   TRANSFERDETAIL.ToLottable08,      
   TRANSFERDETAIL.ToLottable09,      
   TRANSFERDETAIL.ToLottable10,      
   TRANSFERDETAIL.ToLottable11,      
   TRANSFERDETAIL.ToLottable12,      
   TRANSFERDETAIL.ToLottable13,      
   TRANSFERDETAIL.ToLottable14,      
   TRANSFERDETAIL.ToLottable15,
   --(Wan01) - END
   STORER_a.Company,
   STORER_b.Company,
   PACK_a.casecnt,
   PACK_b.casecnt,
   PACK_a.Packuom1,
   PACK_b.Packuom1,
   PACK_a.Packuom3,
   PACK_b.Packuom3,
   TRANSFER.Facility,
   TRANSFER.ToFacility

   SELECT @c_FromStorerkey = FromStorerkey
         ,@c_ToStorerkey = ToStorerkey
   FROM TRANSFER WITH (NOLOCK)
   WHERE TransferKey = @c_Transferkey

   --(Wan01) - START
   SELECT @n_ShowAlllla = 1
   FROM CODELKUP WITH (NOLOCK)
   WHERE ListName = 'REPORTCFG'
   AND   Code     = 'ShowAllLA'
   AND   Storerkey= @c_FromStorerkey
   AND   Long = 'r_dw_transfer_ticket_06'
   AND   ISNULL(Short,0) <> 'N'
   --(Wan01) - END

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
   AND Storerkey = @c_FromStorerkey

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
      SET @c_SQL = N' UPDATE #TMP_TRFTICKET'
                 +  ' SET FromSKU = ' + @c_UDF01 + ' + ' + @c_UDF02 + ' + ' + @c_UDF03
                 +  ' FROM  #TMP_TRFTICKET TMP '
                 +  ' JOIN ' + @c_TableName + ' WITH (NOLOCK) ON  TMP.FromStorerkey = SKU.Storerkey'
                 +                                          ' AND TMP.FromSku = SKU.Sku'

      EXEC ( @c_SQL )
   END

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
   AND Storerkey = @c_ToStorerkey

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
                          THEN 'RTRIM(' + @c_TableName + '.' + @c_UDF01+ ')'
                          ELSE '''' + @c_UDF01 + ''''
                          END

      SET @c_UDF02 = CASE WHEN @n_UDF02IsCol = 1
                          THEN 'RTRIM(' + @c_TableName + '.' + @c_UDF02+ ')'
                          ELSE '''' + @c_UDF02 + ''''
                          END

      SET @c_UDF03 = CASE WHEN @n_UDF03IsCol = 1
                          THEN 'RTRIM(' + @c_TableName + '.' + @c_UDF03 + ')'
                          ELSE '''' + @c_UDF03 + ''''
                          END

      SET @c_SQL = ''

      SET @c_SQL = N' UPDATE #TMP_TRFTICKET'
                 +  ' SET ToSKU = ' + @c_UDF01 + ' + ' + @c_UDF02 + ' + ' + @c_UDF03
                 +  ' FROM  #TMP_TRFTICKET TMP '
                 +  ' JOIN ' + @c_TableName + ' WITH (NOLOCK) ON  TMP.ToStorerkey = SKU.Storerkey'
                 +                                          ' AND TMP.ToSku = SKU.Sku'

      EXEC ( @c_SQL )
   END

   QUIT_SP:
   SELECT  Transferkey
      ,  CustomerRefNo
      ,  ReasonCode
      ,  AddDate
      ,  FromStorerKey
      ,  ToStorerKey
      ,  FromSku
      ,  FromLoc
      ,  FromLot
      ,  FromId
      ,  FromUOM
      ,  FromQty
      ,  LOTTABLE01
      ,  LOTTABLE02
      ,  LOTTABLE03
      ,  LOTTABLE04
      ,  LOTTABLE05
      ,  ToSku
      ,  ToLoc
      ,  ToLot
      ,  ToId
      ,  ToUOM
      ,  ToQty
      ,  tolottable01
      ,  tolottable02
      ,  tolottable03
      ,  tolottable04
      ,  tolottable05
      ,  Type_Desc
      ,  FromCompany
      ,  ToCompany
      ,  fromcasecnt
      ,  tocasecnt
      ,  fromuom1
      ,  touom1
      ,  fromuom3
      ,  touom3
      ,  Username
      ,  Reason_Desc
      ,  Facility
      ,  ToFacility
      --(Wan01) - START
      ,  @n_ShowAlllla
      ,  Lottable06     
      ,  Lottable07     
      ,  Lottable08     
      ,  Lottable09     
      ,  Lottable10     
      ,  Lottable11     
      ,  Lottable12     
      ,  Lottable13     
      ,  Lottable14     
      ,  Lottable15     
      ,  ToLottable06   
      ,  ToLottable07   
      ,  ToLottable08   
      ,  ToLottable09   
      ,  ToLottable10   
      ,  ToLottable11   
      ,  ToLottable12   
      ,  ToLottable13   
      ,  ToLottable14   
      ,  ToLottable15 
      --(Wan01) - END  
   FROM #TMP_TRFTICKET

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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_Transfer_Ticket_06'
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