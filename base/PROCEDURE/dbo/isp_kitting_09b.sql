SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure: isp_kitting_09b                                     */
/* Creation Date: 10-Jul-2013                                           */
/* Copyright: IDS                                                       */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose:  Kitting Report for JJVC                                    */
/*           (SOS#282343)                                               */
/*                                                                      */
/* Input Parameters: @c_kitkey                                          */
/*                                                                      */
/* Usage: Call by dw = r_dw_kitting_09b                                 */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_kitting_09b] (@c_kitkey NVARCHAR(10) )
AS
BEGIN 
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @n_Qty          INT
         , @n_QtyToTake    INT
         , @n_QtyAvailable INT
         , @c_Storerkey    NVARCHAR(15)
         , @c_Sku          NVARCHAR(20)
         , @c_lot          NVARCHAR(10)
         , @c_loc          NVARCHAR(10)
         , @c_id           NVARCHAR(18)
         , @c_Lottable02   NVARCHAR(18)
         , @dt_lottable04  DATETIME
            

   CREATE Table #TempAlloc
      (  KitKey            NVARCHAR(10) NULL
      ,  Storerkey         NVARCHAR(15) NULL
      ,  Sku               NVARCHAR(20) NULL
      ,  Lot               NVARCHAR(10) NULL
      ,  Loc               NVARCHAR(10) NULL 
      ,  ID                NVARCHAR(18) NULL
      ,  Lottable02        NVARCHAR(18) NULL
      ,  Qty               INT          NULL DEFAULT (0) 
      )
   
   SET @n_Qty           = 0
   SET @n_QtyToTake     = 0
   SET @n_QtyAvailable  = 0
   SET @c_Storerkey     = ''
   SET @c_Sku           = ''
   SET @c_Lot           = ''
   SET @c_Loc           = ''
   SET @c_ID            = ''
   SET @c_Lottable02    = ''


   INSERT INTO #TempAlloc
         (  KitKey             
         ,  Storerkey          
         ,  Sku            
         ,  Lot               
         ,  Loc               
         ,  ID                 
         ,  Lottable02         
         ,  Qty 
         )
   SELECT @c_kitkey
        , KITDETAIL.StorerKey  
        , KITDETAIL.SKU 
        , Lot
        , Loc
        , ID
        , ISNULL(RTRIM(KITDETAIL.Lottable02),'')
        , SUM(KITDETAIL.Qty)
   FROM  KITDETAIL WITH (NOLOCK)
   JOIN  KIT       WITH (NOLOCK) ON (KITDETAIL.Kitkey = KIT.Kitkey)
   WHERE KIT.Kitkey     = @c_kitkey
   AND   KITDETAIL.Type = 'F'
   AND   KIT.Status     = '9'          
   GROUP BY KITDETAIL.StorerKey  
         ,  KITDETAIL.SKU
         ,  Lot
         ,  Loc
         ,  ID
         ,  ISNULL(RTRIM(KITDETAIL.Lottable02),'')
   ORDER BY KITDETAIL.SKU

   IF EXISTS (SELECT 1 
              FROM #TempAlloc)
   BEGIN
      GOTO QUIT
   END

   DECLARE CUR_KIT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
   SELECT Storerkey = KITDETAIL.StorerKey  
        , Sku       = KITDETAIL.SKU 
        , Lottable02= ISNULL(RTRIM(KITDETAIL.Lottable02),'')
        , Qty       = SUM(KITDETAIL.ExpectedQty)
   FROM  KITDETAIL WITH (NOLOCK)
   JOIN  KIT       WITH (NOLOCK) ON (KITDETAIL.Kitkey = KIT.Kitkey)
   WHERE KIT.Kitkey     = @c_kitkey
   AND   KITDETAIL.Type = 'F'
   AND   KIT.Status     < '9'          
   GROUP BY KITDETAIL.StorerKey  
         ,  KITDETAIL.SKU
         ,  ISNULL(RTRIM(KITDETAIL.Lottable02),'')
   ORDER BY KITDETAIL.SKU

   OPEN CUR_KIT
   FETCH NEXT FROM CUR_KIT INTO @c_Storerkey
                              , @c_Sku
                              , @c_Lottable02
                              , @n_Qty
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      WHILE @n_Qty > 0  
      BEGIN
         SELECT TOP 1
                @c_lot = LOTxLOCxID.LOT
              , @c_loc = LOTxLOCxID.LOC
              , @c_id  = LOTxLOCxID.ID
              , @n_QtyAvailable= LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked 
              , @dt_Lottable04 = LOTATTRIBUTE.Lottable04
         FROM LOTxLOCxID   WITH (NOLOCK)
         JOIN LOT          WITH (NOLOCK) ON (LOTxLOCxID.Lot = LOT.Lot)
         JOIN LOC          WITH (NOLOCK) ON (LOTxLOCxID.Loc = LOC.Loc)
         JOIN ID           WITH (NOLOCK) ON (LOTxLOCxID.ID  = ID.ID)
         JOIN LOTATTRIBUTE WITH (NOLOCK) ON (LOTxLOCxID.Lot = LOTATTRIBUTE.Lot)
         WHERE LOTxLOCxID.Storerkey = @c_Storerkey
         AND   LOTxLOCxID.Sku   = @c_Sku  
         AND  (LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked > 0)
         AND   LOT.Status       = 'OK'
         AND   LOC.Status       = 'OK'
         AND  (LOC.LocationFlag <>'DAMAGE' AND LOC.LocationFlag  <> 'HOLD')
         AND   ID.Status        = 'OK'
         AND   LOTATTRIBUTE.Lottable02 = @c_Lottable02
         AND NOT EXISTS ( SELECT 1 FROM #TempAlloc
                          WHERE  #TempAlloc.LOT = LOTxLOCxID.LOT
                          AND    #TempAlloc.LOC = LOTxLOCxID.LOC
                          AND    #TempAlloc.ID  = LOTxLOCxID.ID )
         ORDER BY LOTATTRIBUTE.Lottable04
               ,  LOTxLOCxID.LOT
               ,  LOTxLOCxID.LOC
               ,  LOTxLOCxID.ID

         IF @@ROWCOUNT = 0
         BEGIN
            BREAK
         END

         IF @n_QtyAvailable > @n_Qty
         BEGIN 
            SET @n_QtyToTake = @n_Qty
         END
         ELSE
         BEGIN
            SET @n_QtyToTake = @n_QtyAvailable 
         END

         INSERT INTO #TempAlloc
               (  KitKey             
               ,  Storerkey          
               ,  Sku            
               ,  Lot               
               ,  Loc               
               ,  ID                 
               ,  Lottable02         
               ,  Qty 
               )
         VALUES(  @c_KitKey
               ,  @c_Storerkey
               ,  @c_Sku
               ,  @c_lot
               ,  @c_loc
               ,  @c_id
               ,  @c_Lottable02
               ,  @n_QtyToTake
               )
   
         SET @n_Qty = @n_Qty - @n_QtyToTake
      END
      FETCH NEXT FROM CUR_KIT INTO @c_Storerkey
                                 , @c_Sku
                                 , @c_Lottable02
                                 , @n_Qty
   END
   CLOSE CUR_KIT
   DEALLOCATE CUR_KIT

   QUIT:
   SELECT TMP.KitKey
        , TMP.StorerKey
        , TMP.Sku
        , SKU.Descr
        , TMP.Loc
        , QtySuggested = SUM(TMP.Qty)  
        , TMP.Lottable02
   FROM  #TempAlloc TMP
   JOIN  SKU WITH (NOLOCK) ON (TMP.Storerkey = SKU.Storerkey)
                           AND(TMP.Sku       = SKU.Sku)
   GROUP BY TMP.KitKey 
         ,  TMP.StorerKey 
         ,  TMP.Sku 
         ,  Sku.Descr 
         ,  TMP.Loc 
         ,  TMP.Lottable02
  ORDER BY TMP.Sku
         , TMP.Loc
   
  Drop Table #TempAlloc
END

GO