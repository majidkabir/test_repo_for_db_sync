SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: ispPreAL04                                              */
/* Creation Date: 21-JAN-2020                                           */
/* Copyright: LF Logistics                                              */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-11774 SG Philip Morris pre allocation                   */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 30-SEP-2020 NJOW01   1.0   WMS-15380 Aging zone allocation qty limit */
/*                            per order and qty limit per sku per day   */
/* 08-JAN-2021 NJOW02   1.1   WMS-15923 Filter out zone by consignee    */
/* 04-May-2021 NJOW03   1.2   WMS-16977 Set orderdetail.EnteredQTY to 0 */
/*                            for new split line                        */
/************************************************************************/
CREATE PROC [dbo].[ispPreAL04]                      
           @c_OrderKey NVARCHAR(10) 
         , @c_LoadKey  NVARCHAR(10)    
         , @b_Success  INT    OUTPUT  
         , @n_Err      INT    OUTPUT
         , @c_ErrMsg   NVARCHAR(255) OUTPUT  
         , @b_debug    INT = 0   
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt          INT
         , @n_Continue           INT
         , @n_Qty                INT
         , @n_OpenQty            INT
         , @n_QtyLeftToFulfill   INT
         , @n_QtyAvailable       INT
         , @c_Facility           NVARCHAR(5)
         , @c_OrderLineNumber    NVARCHAR(5)
         , @c_Storerkey          NVARCHAR(15)
         , @c_Sku                NVARCHAR(20)
         , @c_AltSku             NVARCHAR(20)
         , @c_AltSku_Prev        NVARCHAR(20)
         , @c_Packkey            NVARCHAR(10)
         , @c_UOM                NVARCHAR(10)
         , @c_Lot                NVARCHAR(10)
         , @c_Lottable01         NVARCHAR(18)
         , @c_Lottable02         NVARCHAR(18)
         , @c_Lottable03         NVARCHAR(18)
         , @dt_Lottable04        DATETIME    
         , @dt_Lottable05        DATETIME    
         , @c_Lottable06         NVARCHAR(30)
         , @c_Lottable07         NVARCHAR(30)
         , @c_Lottable08         NVARCHAR(30)
         , @c_Lottable09         NVARCHAR(30)
         , @c_Lottable10         NVARCHAR(30)
         , @c_Lottable11         NVARCHAR(30)
         , @c_Lottable12         NVARCHAR(30)
         , @dt_Lottable13        DATETIME    
         , @dt_Lottable14        DATETIME    
         , @dt_Lottable15        DATETIME  
         , @c_Lottable01_Prev    NVARCHAR(18)
         , @c_Lottable02_Prev    NVARCHAR(18)
         , @c_Lottable03_Prev    NVARCHAR(18)
         , @dt_Lottable04_Prev   DATETIME    
         , @dt_Lottable05_Prev   DATETIME    
         , @c_Lottable06_Prev    NVARCHAR(30)
         , @c_Lottable07_Prev    NVARCHAR(30)
         , @c_Lottable08_Prev    NVARCHAR(30)
         , @c_Lottable09_Prev    NVARCHAR(30)
         , @c_Lottable10_Prev    NVARCHAR(30)
         , @c_Lottable11_Prev    NVARCHAR(30)
         , @c_Lottable12_Prev    NVARCHAR(30)
         , @dt_Lottable13_Prev   DATETIME    
         , @dt_Lottable14_Prev   DATETIME    
         , @dt_Lottable15_Prev   DATETIME  
         , @c_PreAllocatePickDetailKey NVARCHAR(10)
         , @c_SQL          NVARCHAR(MAX)
         , @c_SQLParms           NVARCHAR(MAX)           --(Wan01)
         , @c_AddWhereSQL        NVARCHAR(MAX)                              
         , @n_UOMQty             INT                     --(Wan01)
         , @n_PackQty            INT                     --(Wan01)
         , @n_CaseCnt            FLOAT                   --(Wan01)
         , @n_Pallet             FLOAT                   --(Wan01)
         , @c_Consigneekey       NVARCHAR(15)            --(Wan01)
         , @n_skucnt             INT
         , @n_NewOpenQty         INT  --Fix NJOW03

   --NJOW01
   DECLARE      
           @n_AgingQtyPerOrd     INT                     
         , @n_AgingQtyPerOrdBal  INT                     
         , @n_SkuQtyPerDay       INT
         , @n_SkuQtyPerDayBal    INT 
         , @n_TotQtyAllocated    INT
         , @n_TotQtyPreAllocated INT         
         
   DECLARE @c_sku_priority1      NVARCHAR(20)
         , @c_sku_priority2      NVARCHAR(20)
         , @c_sku_priority3      NVARCHAR(20)
         , @c_sku_priority4      NVARCHAR(20)
         , @c_sku_priority5      NVARCHAR(20)
         , @c_Agingpickzone      NVARCHAR(10)               
         , @C_pickzone           NVARCHAR(10)
         , @n_inner              INT
         , @n_otherunit1         INT
         , @n_seq                INT

   CREATE TABLE #TMP_PREALLOC
      (  RowRef            INT            IDENTITY(1,1)
      ,  Orderkey          NVARCHAR(10)   NOT NULL DEFAULT ('')
      --,  OrderLineNumber   NVARCHAR(5)    NOT NULL DEFAULT ('')
      ,  Storerkey         NVARCHAR(15)   NOT NULL DEFAULT ('')
      ,  Lot               NVARCHAR(10)   NOT NULL DEFAULT ('')
      ,  Sku               NVARCHAR(20)   NOT NULL DEFAULT ('')
      ,  AltSku            NVARCHAR(20)   NOT NULL DEFAULT ('')
      ,  UOM               NVARCHAR(10)   NOT NULL DEFAULT ('')                                    --(Wan01)
      ,  UOMQty            INT            NOT NULL DEFAULT (0)                                     --(Wan01)
      ,  Lottable01        NVARCHAR(18)   NOT NULL DEFAULT('')
      ,  Lottable02        NVARCHAR(18)   NOT NULL DEFAULT('')
      ,  Lottable03        NVARCHAR(18)   NOT NULL DEFAULT('')
      ,  Lottable04        DATETIME       NULL  
      ,  Lottable05        DATETIME       NULL  
      ,  Lottable06        NVARCHAR(30)   NOT NULL DEFAULT('')
      ,  Lottable07        NVARCHAR(30)   NOT NULL DEFAULT('')
      ,  Lottable08        NVARCHAR(30)   NOT NULL DEFAULT('')
      ,  Lottable09        NVARCHAR(30)   NOT NULL DEFAULT('')
      ,  Lottable10        NVARCHAR(30)   NOT NULL DEFAULT('')
      ,  Lottable11        NVARCHAR(30)   NOT NULL DEFAULT('')
      ,  Lottable12        NVARCHAR(30)   NOT NULL DEFAULT('')
      ,  Lottable13        DATETIME       NULL  
      ,  Lottable14        DATETIME       NULL  
      ,  Lottable15        DATETIME       NULL  
      ,  Qty               INT            NOT NULL DEFAULT (0)
      ,  QtyLeftToFulfill  INT            NOT NULL DEFAULT (0)
      )

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue  = 1
   SET @b_Success = 1
   SET @c_ErrMsg  = ''
   
   DECLARE CUR_OD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT OH.Facility
         ,OD.Storerkey
         ,OD.AltSku
         ,Lottable01 = ISNULL(RTRIM(OD.Lottable01),'')      
         ,Lottable02 = ISNULL(RTRIM(OD.Lottable02),'')      
         ,Lottable03 = ISNULL(RTRIM(OD.Lottable03),'')      
         ,Lottable04 = ISNULL(OD.Lottable04,'19000101')   
         ,Lottable05 = ISNULL(OD.Lottable05,'19000101')   
         ,Lottable06 = ISNULL(RTRIM(OD.Lottable06),'')      
         ,Lottable07 = ISNULL(RTRIM(OD.Lottable07),'')      
         ,Lottable08 = ISNULL(RTRIM(OD.Lottable08),'')      
         ,Lottable09 = ISNULL(RTRIM(OD.Lottable09),'')      
         ,Lottable10 = ISNULL(RTRIM(OD.Lottable10),'')      
         ,Lottable11 = ISNULL(RTRIM(OD.Lottable11),'')      
         ,Lottable12 = ISNULL(RTRIM(OD.Lottable12),'')      
         ,Lottable13 = ISNULL(OD.Lottable13,'19000101')   
         ,Lottable14 = ISNULL(OD.Lottable14,'19000101')   
         ,Lottable15 = ISNULL(OD.Lottable15,'19000101') 
         ,QtyLeftToFulfill = SUM(OD.OpenQty - OD.QtyAllocated - OD.QtyPicked - OD.QtyPreAllocated)
         ,Consigneekey = ISNULL(RTRIM(OH.Consigneekey),'')                                         --(Wan01)
   FROM ORDERS      OH WITH (NOLOCK) 
   JOIN ORDERDETAIL OD WITH (NOLOCK) ON (OH.Orderkey = OD.Orderkey)
   WHERE OH.Orderkey = @c_Orderkey                                                                  
   AND OD.OpenQty - OD.QtyAllocated - OD.QtyPicked - OD.QtyPreAllocated > 0
   AND OD.AltSku <> ''
   GROUP BY OH.Facility
         ,  OD.Storerkey
         ,  OD.AltSku
         ,  ISNULL(RTRIM(OD.Lottable01),'')   
         ,  ISNULL(RTRIM(OD.Lottable02),'')   
         ,  ISNULL(RTRIM(OD.Lottable03),'')   
         ,  ISNULL(OD.Lottable04,'19000101')
         ,  ISNULL(OD.Lottable05,'19000101')
         ,  ISNULL(RTRIM(OD.Lottable06),'')   
         ,  ISNULL(RTRIM(OD.Lottable07),'')   
         ,  ISNULL(RTRIM(OD.Lottable08),'')   
         ,  ISNULL(RTRIM(OD.Lottable09),'')   
         ,  ISNULL(RTRIM(OD.Lottable10),'')   
         ,  ISNULL(RTRIM(OD.Lottable11),'')   
         ,  ISNULL(RTRIM(OD.Lottable12),'')   
         ,  ISNULL(OD.Lottable13,'19000101')
         ,  ISNULL(OD.Lottable14,'19000101')
         ,  ISNULL(OD.Lottable15,'19000101')
         ,  ISNULL(RTRIM(OH.Consigneekey),'')                                                      --(Wan01)

   OPEN CUR_OD
   
   FETCH NEXT FROM CUR_OD INTO  @c_Facility
                              , @c_Storerkey
                              , @c_AltSku
                              , @c_Lottable01     
                              , @c_Lottable02     
                              , @c_Lottable03     
                              , @dt_Lottable04    
                              , @dt_Lottable05    
                              , @c_Lottable06     
                              , @c_Lottable07     
                              , @c_Lottable08     
                              , @c_Lottable09     
                              , @c_Lottable10     
                              , @c_Lottable11     
                              , @c_Lottable12     
                              , @dt_Lottable13    
                              , @dt_Lottable14    
                              , @dt_Lottable15 
                              , @n_QtyLeftToFulfill     
                              , @c_ConsigneeKey                                                    --(Wan01)                               

   WHILE @@FETCH_STATUS <> -1
   BEGIN

      IF @b_debug = 1
      BEGIN
         SELECT @c_AltSku 'AltSku', @n_QtyLeftToFulfill 'QtyLeftToFulfill' 
         SELECT @c_Consigneekey 'Consigneekey'
      END

      SET @c_AddWhereSQL = ''

      IF @c_Lottable01 <> ''
      BEGIN 
         SET @c_AddWhereSQL = @c_AddWhereSQL + N' AND LOTATTRIBUTE.Lottable01 = @c_Lottable01'
      END

      IF @c_Lottable02 <> ''
      BEGIN 
         SET @c_AddWhereSQL = @c_AddWhereSQL + N' AND LOTATTRIBUTE.Lottable02 = @c_Lottable02'
      END

      IF @c_Lottable03 <> ''
      BEGIN 
         SET @c_AddWhereSQL = @c_AddWhereSQL + N' AND LOTATTRIBUTE.Lottable03 = @c_Lottable03'
      END

      IF CONVERT(NVARCHAR(8), @dt_Lottable04, 112) <> '19000101'
      BEGIN 
         SET @c_AddWhereSQL = @c_AddWhereSQL + N' AND LOTATTRIBUTE.Lottable04 = CONVERT(DATETIME, CONVERT(NVARCHAR(8), @dt_Lottable04, 112))'
      END

      IF CONVERT(NVARCHAR(8), @dt_Lottable05, 112) <> '19000101'
      BEGIN 
         SET @c_AddWhereSQL = @c_AddWhereSQL + N' AND LOTATTRIBUTE.Lottable05 = CONVERT(DATETIME, CONVERT(NVARCHAR(8), @dt_Lottable05, 112))'
      END

      IF @c_Lottable06 <> ''
      BEGIN 
         SET @c_AddWhereSQL = @c_AddWhereSQL + N' AND LOTATTRIBUTE.Lottable06 = @c_Lottable06'
      END

      IF @c_Lottable07 <> ''
      BEGIN 
         SET @c_AddWhereSQL = @c_AddWhereSQL + N' AND LOTATTRIBUTE.Lottable07 = @c_Lottable07'
      END
      
      IF @c_Lottable08 <> ''
      BEGIN 
         SET @c_AddWhereSQL = @c_AddWhereSQL + N' AND LOTATTRIBUTE.Lottable08 = @c_Lottable08'
      END

      IF @c_Lottable09 <> ''
      BEGIN 
         SET @c_AddWhereSQL = @c_AddWhereSQL + N' AND LOTATTRIBUTE.Lottable09 = @c_Lottable09'
      END

      IF @c_Lottable10 <> ''
      BEGIN 
         SET @c_AddWhereSQL = @c_AddWhereSQL + N' AND LOTATTRIBUTE.Lottable10 = @c_Lottable10'
      END

      IF @c_Lottable11 <> ''
      BEGIN 
         SET @c_AddWhereSQL = @c_AddWhereSQL + N' AND LOTATTRIBUTE.Lottable11 = @c_Lottable11'
      END

      IF @c_Lottable12 <> ''
      BEGIN 
         SET @c_AddWhereSQL = @c_AddWhereSQL + N' AND LOTATTRIBUTE.Lottable12 = @c_Lottable12'
      END

      IF CONVERT(NVARCHAR(8), @dt_Lottable13, 112) <> '19000101'
      BEGIN 
         SET @c_AddWhereSQL = @c_AddWhereSQL + N' AND LOTATTRIBUTE.Lottable13 = CONVERT(DATETIME, CONVERT(NVARCHAR(8), @@dt_Lottable13, 112))' 
      END

      IF CONVERT(NVARCHAR(8), @dt_Lottable14, 112) <> '19000101'
      BEGIN 
         SET @c_AddWhereSQL = @c_AddWhereSQL + N' AND LOTATTRIBUTE.Lottable14 = CONVERT(DATETIME, CONVERT(NVARCHAR(8), @@dt_Lottable14, 112))'
      END

      IF CONVERT(NVARCHAR(8), @dt_Lottable15, 112) <> '19000101'
      BEGIN 
         SET @c_AddWhereSQL = @c_AddWhereSQL + N' AND LOTATTRIBUTE.Lottable15 = CONVERT(DATETIME, CONVERT(NVARCHAR(8), @@dt_Lottable15, 112))'
      END
      
      SELECT @c_Sku_Priority1 = '', @c_Sku_Priority2= '', @c_Sku_Priority3 = '', @c_Sku_Priority4 ='', @c_Sku_Priority5 ='' 
      
      SELECT @c_Sku_Priority1  = ISNULL(CL.UDF01,''),
             @c_Sku_Priority2  = ISNULL(CL.UDF02,''),
             @c_Sku_Priority3  = ISNULL(CL.UDF03,''),
             @c_Sku_Priority4  = ISNULL(CL.UDF04,''),
             @c_Sku_Priority5  = ISNULL(CL.UDF05,''),
             @c_AgingPickZone  = ISNULL(CL.Short,''),
             @n_AgingQtyPerOrd = CASE WHEN ISNUMERIC(CL.Long) = 1 THEN CAST(CL.Long AS INT) ELSE 0 END --NJOW01
      FROM CODELKUP CL (NOLOCK)
      JOIN ORDERS O (NOLOCK) ON CL.Code = O.Priority AND CL.Storerkey = O.Storerkey 
      WHERE O.Orderkey = @c_Orderkey
      AND CL.Listname = 'PMIALLOC'
      AND CL.Code2 = @c_AltSku
      
      SET @n_AgingQtyPerOrdBal = @n_AgingQtyPerOrd --NJOW01 
            
      IF @@ROWCOUNT = 0
         GOTO NEXT_ALTSKU
      
      --IF @c_AgingPickZone = 'YES'
      --BEGIN
      --   SET @c_AddWhereSQL = @c_AddWhereSQL + N' AND LOC.PickZone = ''PMIAGING'' '         
      --END

      SET @n_skucnt = 0
      WHILE @n_QtyLeftToFulfill > 0 AND @n_skucnt < 5 
      BEGIN
      	 SELECT @c_Sku = '', @n_Casecnt = 0, @n_Inner = 0, @n_Otherunit1 = 0
      	 SELECT @n_SkuQtyPerDay = 0, @n_SkuQtyPerDayBal = 0, @n_TotQtyAllocated = 0, @n_TotQtyPreAllocated = 0 --NJOW01
      	 
      	 SET @n_skucnt = @n_skucnt +  1
      	 
      	 IF @n_skucnt = 1 
      	    SET @c_Sku = @c_Sku_Priority1
      	 IF @n_skucnt = 2 
      	    SET @c_Sku = @c_Sku_Priority2
      	 IF @n_skucnt = 3 
      	    SET @c_Sku = @c_Sku_Priority3
      	 IF @n_skucnt = 4 
      	    SET @c_Sku = @c_Sku_Priority4
      	 IF @n_skucnt = 5 
      	    SET @c_Sku = @c_Sku_Priority5
      	          	    
      	 IF ISNULL(@c_SKU,'') = ''
      	    GOTO NEXT_SKU      	          	    
      	       	 
      	 SELECT @n_Casecnt = PACK.Casecnt, 
      	        @n_Inner = PACK.InnerPack,
      	        @n_otherunit1 = PACK.Otherunit1,
      	        @n_SkuQtyPerDay = CASE WHEN ISNUMERIC(SKU.Busr1) = 1THEN CAST(SKU.Busr1 AS INT) ELSE 0 END --NJOW01
      	 FROM SKU (NOLOCK)
      	 JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey
      	 WHERE SKU.Sku = @c_Sku
      	 AND SKU.Storerkey = @c_Storerkey
      	 
      	 IF @n_SkuQtyPerDay > 0  --NJOW01
      	 BEGIN
      	    SELECT @n_TotQtyAllocated = SUM(Qty)
      	    FROM PICKDETAIL PD (NOLOCK)
      	    WHERE Storerkey  = @c_Storerkey
      	    AND Sku = @c_Sku
      	    AND DATEDIFF(day, PD.AddDate, GETDATE()) = 0
      	    
      	    SELECT @n_TotQtyPreAllocated = SUM(Qty)
      	    FROM #TMP_PREALLOC TP
      	    WHERE Storerkey  = @c_Storerkey
      	    AND Sku = @c_Sku
      	    
      	    SET @n_SkuQtyPerDayBal = @n_SkuQtyPerDay - ISNULL(@n_TotQtyAllocated,0) - ISNULL(@n_TotQtyPreAllocated,0)
      	 END
      	 
      	 IF @c_AgingPickZone = 'YES'
      	 BEGIN
      	    DECLARE CUR_UOM CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      	       SELECT 1,'PMIAGING', '6', 1  --master unit  (pkt)
      	       UNION
      	       SELECT 2,'PMICASEPZ', '2', @n_casecnt  --case  (ctn)
      	       UNION
      	       SELECT 3,'PMICARPZ', '4', @n_otherunit1   --other1  (box)
      	       UNION 
      	       SELECT 4,'PMIPACKPZ', '3', @n_Inner  --Inner  (1 pkt)
      	       ORDER BY 1
      	 END
      	 ELSE
      	 BEGIN      	  
      	    DECLARE CUR_UOM CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      	       SELECT 1,'PMICASEPZ', '2', @n_casecnt  --case  (ctn)
      	       UNION
      	       SELECT 2,'PMICARPZ', '4', @n_otherunit1   --other1  (box)
      	       UNION 
      	       SELECT 3,'PMIPACKPZ', '3', @n_Inner  --Inner  (1 pkt)
      	       ORDER BY 1
      	 END
      	 
         OPEN CUR_UOM  
         
         FETCH NEXT FROM CUR_UOM INTO @n_seq, @c_PickZone, @c_UOM, @n_PackQty
                       
         WHILE @@FETCH_STATUS = 0 AND @n_QtyLeftToFulfill > 0
         BEGIN     	               	 
         	 IF @n_PackQty <= 0 
         	    GOTO NEXT_UOM
         	 
         	 --NJOW02
         	 IF EXISTS(SELECT 1
         	           FROM CODELKUP CL (NOLOCK)
         	           WHERE CL.Listname = 'PMICUST'
         	           AND CL.Code = @c_Consigneekey
         	           AND @c_PickZone IN (SELECT PZ.ColValue FROM dbo.fnc_DelimSplit(',',CL.Long) PZ))      	   
         	  BEGIN
         	     GOTO NEXT_UOM
         	  END                   	    
         	   	 
            SET @c_SQL = 
                     N'DECLARE CUR_LLI CURSOR FAST_FORWARD READ_ONLY FOR'
                     + ' SELECT LOTxLOCxID.Lot'
                     + ',LOTxLOCxID.Sku'
                     + ',QtyAvail=SUM(LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked - ISNULL(PR.PreAllocatedQty,0))'
                     + ',PACK.CaseCnt'                                                                   --(Wan01) 
                     + ',PACK.Pallet'                                                                    --(Wan01) 
                     + ' FROM   SKU  WITH (NOLOCK)'
                     + ' JOIN   PACK WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)'
                     + ' JOIN   LOTxLOCxID WITH (NOLOCK) ON (SKU.Storerkey = LOTxLOCxID.Storerkey)'
                     +                                 ' AND(SKU.Sku = LOTxLOCxID.Sku)'
                     + ' JOIN   LOT WITH (NOLOCK) ON (LOTxLOCxID.Lot = LOT.Lot)'
                     +                          ' AND(LOT.Status = ''OK'')'
                     + ' JOIN   LOC WITH (NOLOCK) ON (LOTxLOCxID.Loc = LOC.Loc)' 
                     +                          ' AND(LOC.LocationFlag NOT IN (''DAMAGE'', ''HOLD''))'  
                     +                          ' AND(LOC.Status = ''OK'')'
                     + ' JOIN   ID  WITH (NOLOCK) ON (LOTxLOCxID.ID = ID.ID)'
                     +                          ' AND(ID.Status = ''OK'')'   
                     + ' JOIN   LOTATTRIBUTE WITH (NOLOCK) ON (LOTxLOCxID.Lot = LOTATTRIBUTE.Lot)'
                     + ' LEFT JOIN ( SELECT P.Lot, O.Facility, PreAllocatedQty = SUM(P.Qty)' 
                     +             ' FROM ORDERS O WITH (NOLOCK)'
                     +             ' JOIN PREALLOCATEPICKDETAIL P WITH (NOLOCK) ON (O.Orderkey = P.Orderkey)'
                     +             ' WHERE O.Facility = @c_Facility '
                     +             ' AND   O.Storerkey= @c_Storerkey'
                     +             ' AND   P.Sku = @c_sku'
                     +             ' AND   O.Status < ''9'''
                     +             ' GROUP BY P.Lot, O.Facility) PR'
                     +             ' ON (LOTxLOCxID.Lot = PR.Lot)'
                     +             ' AND(LOC.Facility = PR.Facility)'                  
                     + ' WHERE SKU.Storerkey = @c_Storerkey'
                     --+ ' AND   SKU.AltSku    = @c_AltSku'
                     + ' AND   SKU.Sku       = @c_Sku'
                     + ' AND   LOC.Facility  = @c_Facility'
                     + ' AND   LOC.Pickzone  = @c_PickZone'
                     + @c_AddWhereSQL
                     + ' AND   LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked - ISNULL(PR.PreAllocatedQty,0) > 0'
                     + ' GROUP BY LOTxLOCxID.Lot'
                     +        ',  LOTxLOCxID.Sku'
                     +        ',  LOTATTRIBUTE.Lottable06'  
                     +        ',  ISNULL(SKU.BUSR5,'''')'   
                     +        ',  LOTATTRIBUTE.Lottable15'
                     +        ',  PACK.CaseCnt'                                                          --(Wan01) 
                     +        ',  PACK.Pallet'                                                           --(Wan01) 
                     +        ',  LOTATTRIBUTE.Lottable05' --NJOW01
--                     + ' ORDER BY LOTATTRIBUTE.Lottable06 DESC'
                    -- + ' ,CASE LOTxLOCxID.Sku WHEN ' + RTRIM(@c_SkuPriority1) + ' THEN 1 WHEN  ' + RTRIM(@c_SkuPriority2) + ' THEN 2 WHEN '  + RTRIM(@c_SkuPriority3) + ' THEN 3 WHEN '   + RTRIM(@c_SkuPriority4) + ' THEN 4 WHEN '   + RTRIM(@c_SkuPriority5) + ' THEN 5 ELSE 6 END' --NJOW01  
--                     +        ',  ISNULL(SKU.BUSR5,'''')'  
                     +        ' ORDER BY LOTATTRIBUTE.Lottable15'
                     +        ',  LOTATTRIBUTE.Lottable05' --NJOW01                                     
                     --(Wan01) - START
                     + CASE WHEN @c_Consigneekey = 'PMS1'  
                            THEN ''
                            ELSE ', CASE WHEN PACK.Pallet > 0 AND FLOOR(SUM(LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked - ISNULL(PR.PreAllocatedQty,0)) / PACK.Pallet) > 0 '
                                     + ' THEN 1'
                                     + ' WHEN PACK.CaseCnt> 0 AND FLOOR(SUM(LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked - ISNULL(PR.PreAllocatedQty,0)) / PACK.CaseCnt)> 0 '
                                     + ' THEN 2'
                                     + ' ELSE 9'  
                                     + ' END'  
                            END
                     --(Wan01) - END
                     +        ',  LOTxLOCxID.Sku'
            
            --EXEC (@c_SQL)
            SEt @c_SQLParms = N'@c_Facility     NVARCHAR(5)'  
                            + ',@c_StorerKey    NVARCHAR(15)'
                            + ',@c_AltSku       NVARCHAR(20)'
                            + ',@c_Sku          NVARCHAR(20)'
                            + ',@c_Lottable01   NVARCHAR(18)'
                            + ',@c_Lottable02   NVARCHAR(18)'
                            + ',@c_Lottable03   NVARCHAR(18)'
                            + ',@dt_Lottable04  DATETIME'
                            + ',@dt_Lottable05  DATETIME'
                            + ',@c_Lottable06   NVARCHAR(30)'
                            + ',@c_Lottable07   NVARCHAR(30)'
                            + ',@c_Lottable08   NVARCHAR(30)'
                            + ',@c_Lottable09   NVARCHAR(30)'
                            + ',@c_Lottable10   NVARCHAR(30)'
                            + ',@c_Lottable11   NVARCHAR(30)'
                            + ',@c_Lottable12   NVARCHAR(30)'
                            + ',@dt_Lottable13  DATETIME'
                            + ',@dt_Lottable14  DATETIME'
                            + ',@dt_Lottable15  DATETIME'
                            + ',@c_PickZone     NVARCHAR(10)'
            
            EXEC sp_executesql @c_SQL                                                                                   
               ,@c_SQLParms     
               ,@c_Facility                                                                                                  
               ,@c_StorerKey   
               ,@c_AltSku   
               ,@c_Sku   
               ,@c_Lottable01                                                                                          
     	         ,@c_Lottable02
               ,@c_Lottable03
               ,@dt_Lottable04  
               ,@dt_Lottable05 
               ,@c_Lottable06                                                                                         
     	         ,@c_Lottable07
               ,@c_Lottable08
               ,@c_Lottable09  
               ,@c_Lottable10  
               ,@c_Lottable11                                                                                          
     	         ,@c_Lottable12
               ,@dt_Lottable13
               ,@dt_Lottable14  
               ,@dt_Lottable15  
               ,@c_PickZone                                                                                          
            
            OPEN CUR_LLI
      
            FETCH NEXT FROM CUR_LLI INTO @c_Lot, @c_Sku, @n_QtyAvailable, @n_CaseCnt, @n_Pallet          --(Wan01)
            WHILE @@FETCH_STATUS <> -1 AND @n_QtyLeftToFulfill > 0 
            BEGIN
               IF @b_debug = 1
               BEGIN
                  SELECT @c_Lot 'Lot', @c_Sku 'Sku', @n_QtyAvailable 'QtyAvailable' 
                  SELECT @n_CaseCnt 'CaseCnt',@n_Pallet 'Pallet' 
                  SELECT @c_Consigneekey 'Consigneekey'
               END
            
               --(Wan01) - START
               /*
               SET @c_UOM = '6'
               SEt @n_Packqty = 1
               IF @c_Consigneekey = 'PMS1'
               BEGIN 
                  IF @n_Pallet > 0 AND FLOOR(@n_QtyAvailable/@n_Pallet) > 0 
                  BEGIN 
                     SET @c_UOM = '1'
                     SET @n_Packqty = @n_Pallet
                     SET @n_QtyAvailable = FLOOR(@n_QtyAvailable/@n_Pallet) * @n_Pallet
                     --SET @n_QtyLeftToFulfill = FLOOR(@n_QtyLeftToFulfill/@n_Pallet) * @n_Pallet
                  END
                  ELSE IF @n_CaseCnt > 0 AND FLOOR(@n_QtyAvailable/@n_CaseCnt) > 0 
                  BEGIN
                     SET @c_UOM = '2'
                     SET @n_Packqty = @n_CaseCnt
                     SET @n_QtyAvailable = FLOOR(@n_QtyAvailable/@n_CaseCnt) * @n_CaseCnt
                     --SET @n_QtyLeftToFulfill = FLOOR(@n_QtyLeftToFulfill/@n_CaseCnt) * @n_CaseCnt
                  END
            
                  IF @c_UOM = '6'
                  BEGIN
                     GOTO NEXT_INV
                  END
               END
               */
               --(Wan01) - END
               
               --NJOW01 S
               IF @c_PickZone = 'PMIAGING' AND @n_AgingQtyPerOrd > 0 AND @n_QtyAvailable > @n_AgingQtyPerOrdBal  --Exceeded aging qty per order
               BEGIN
                  SET @n_QtyAvailable = @n_AgingQtyPerOrdBal               	
               END
               
               IF @n_SkuQtyPerDay > 0 AND @n_QtyAvailable > @n_SkuQtyPerDayBal  --Exceeded qty per sku per day
               BEGIN
                  SET @n_QtyAvailable = @n_SkuQtyPerDayBal
               END
               --NJOW01 E                             
            
               IF @n_QtyLeftToFulfill > @n_QtyAvailable
               BEGIN
                  SET @n_OpenQty = FLOOR(@n_QtyAvailable / @n_PackQty) * @n_PackQty
               END
               ELSE
               BEGIN
                  SET @n_OpenQty = FLOOR(@n_QtyLeftToFulfill / @n_PackQty) * @n_PackQty 
               END
            
               SET @n_UOMQty = @n_OpenQty / @n_Packqty                                                   --(Wan01)
            
               SET @n_QtyLeftToFulfill = @n_QtyLeftToFulfill - @n_OpenQty
                              
               --NJOW01 S
               IF @c_PickZone = 'PMIAGING' AND @n_AgingQtyPerOrd > 0 
               BEGIN
                  SET @n_AgingQtyPerOrdBal = @n_AgingQtyPerOrdBal - @n_OpenQty
               END  
               
                IF @n_SkuQtyPerDay > 0                
                BEGIN
                	 SET @n_SkuQtyPerDayBal = @n_SkuQtyPerDayBal - @n_OpenQty
                END
               --NJOW01 E
            
               IF @b_debug = 1
               BEGIN
                  SELECT @n_QtyLeftToFulfill 'QtyLeftToFulfill',@n_QtyAvailable 'QtyAvailable' 
                  SELECT @c_UOM 'UOM', @n_Packqty 'Packqty' 
                  SELECT @n_UOMQty 'UOMQty', @n_OpenQty 'OpenQty' 
               END
            
               IF @n_OpenQty > 0                                                                         --(Wan01)
               BEGIN
                  INSERT INTO #TMP_PREALLOC
                           (  Orderkey
                           ,  Lot
                           ,  Storerkey 
                           ,  Sku   
                           ,  AltSku
                           ,  UOM                                                                        --(Wan01)
                           ,  UOMQty                                                                     --(Wan01)
                           ,  Lottable01     
                           ,  Lottable02     
                           ,  Lottable03     
                           ,  Lottable04    
                           ,  Lottable05    
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
                           ,  Qty
                           )
                  VALUES   (  @c_Orderkey
                           ,  @c_Lot
                           ,  @c_Storerkey 
                           ,  @c_Sku
                           ,  @c_AltSku
                           ,  @c_UOM                                                                     --(Wan01)
                           ,  @n_UOMQty                                                                  --(Wan01)
                           ,  @c_Lottable01     
                           ,  @c_Lottable02     
                           ,  @c_Lottable03     
                           ,  @dt_Lottable04    
                           ,  @dt_Lottable05    
                           ,  @c_Lottable06     
                           ,  @c_Lottable07     
                           ,  @c_Lottable08     
                           ,  @c_Lottable09     
                           ,  @c_Lottable10     
                           ,  @c_Lottable11     
                           ,  @c_Lottable12     
                           ,  @dt_Lottable13    
                           ,  @dt_Lottable14    
                           ,  @dt_Lottable15 
                           ,  @n_OpenQty
                           )
            
                  IF @@ERROR <> 0 
                  BEGIN
                     SET @n_Continue = 3    
                     SET @n_Err = 63500    
                     SET @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Insert Failed Into Table #TMP_PREALLOC. (ispPreAL04)'
                     GOTO QUIT_SP  
                  END
               END
               
               NEXT_INV:          
                                                                                      --(Wan01) 
               FETCH NEXT FROM CUR_LLI INTO @c_Lot, @c_Sku, @n_QtyAvailable, @n_CaseCnt, @n_Pallet       --(Wan01)    
            END
            CLOSE CUR_LLI
            DEALLOCATE CUR_LLI
            
            IF @b_debug = 1
            BEGIN
               SELECT 'ORDERDETAIL Loop'
               SELECT @n_QtyLeftToFulfill 'QtyLeftToFulfill',@c_AltSku 'AltSku' 
            END
            
            UPDATE #TMP_PREALLOC
               SET QtyLeftToFulfill = @n_QtyLeftToFulfill
            WHERE ALTSKU = @c_AltSku
            AND   Lottable01 = @c_Lottable01   --fix lottable filter NJOW03
            AND   Lottable02 = @c_Lottable02
            AND   Lottable03 = @c_Lottable03
            AND   ISNULL(Lottable04,'19000101') = @dt_Lottable04
            AND   ISNULL(Lottable05,'19000101') = @dt_Lottable05
            AND   Lottable06 = @c_Lottable06
            AND   Lottable07 = @c_Lottable07
            AND   Lottable08 = @c_Lottable08
            AND   Lottable09 = @c_Lottable09
            AND   Lottable10 = @c_Lottable10
            AND   Lottable11 = @c_Lottable11
            AND   Lottable12 = @c_Lottable12
            AND   ISNULL(Lottable13,'19000101') = @dt_Lottable13
            AND   ISNULL(Lottable14,'19000101') = @dt_Lottable14
            AND   ISNULL(Lottable15,'19000101') = @dt_Lottable15            
            
            IF @@ERROR <> 0 
            BEGIN
               SET @n_Continue = 3    
               SET @n_Err = 63510    
               SET @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Update Failed On Table #TMP_PREALLOC. (ispPreAL04)'
               GOTO QUIT_SP  
            END
            
            NEXT_UOM:
            
            FETCH NEXT FROM CUR_UOM INTO @n_seq, @c_PickZone, @c_UOM, @n_PackQty            
         END --uom,pickzone loop
         CLOSE CUR_UOM
         DEALLOCATE CUR_UOM
         
         --if the sku still have stock proceed to next altsku
         IF @n_QtyLeftToFulfill > 0 
         BEGIN         	         	
         	  SET @n_QtyAvailable = 0
         	  
            SET @c_SQL =
                 N'SELECT @n_QtyAvailable = SUM(QtyAvai) FROM ' 
                + '(SELECT LOTxLOCxID.Lot, QtyAvai=SUM(LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked - ISNULL(PR.PreAllocatedQty,0) - ISNULL(PR2.PreAllocatedQty,0))'
                + ' FROM   SKU  WITH (NOLOCK)'
                + ' JOIN   PACK WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)'
                + ' JOIN   LOTxLOCxID WITH (NOLOCK) ON (SKU.Storerkey = LOTxLOCxID.Storerkey)'
                +                                 ' AND(SKU.Sku = LOTxLOCxID.Sku)'
                + ' JOIN   LOT WITH (NOLOCK) ON (LOTxLOCxID.Lot = LOT.Lot)'
                +                          ' AND(LOT.Status = ''OK'')'
                + ' JOIN   LOC WITH (NOLOCK) ON (LOTxLOCxID.Loc = LOC.Loc)' 
                +                          ' AND(LOC.LocationFlag NOT IN (''DAMAGE'', ''HOLD''))'  
                +          ' AND(LOC.Status = ''OK'')'
                + ' JOIN   ID  WITH (NOLOCK) ON (LOTxLOCxID.ID = ID.ID)'
                +                          ' AND(ID.Status = ''OK'')'   
                + ' JOIN   LOTATTRIBUTE WITH (NOLOCK) ON (LOTxLOCxID.Lot = LOTATTRIBUTE.Lot)'
                + ' LEFT JOIN ( SELECT P.Lot, O.Facility, PreAllocatedQty = SUM(P.Qty)' 
                +             ' FROM ORDERS O WITH (NOLOCK)'
                +             ' JOIN PREALLOCATEPICKDETAIL P WITH (NOLOCK) ON (O.Orderkey = P.Orderkey)'
                +             ' WHERE O.Facility = @c_Facility '
                +             ' AND   O.Storerkey= @c_Storerkey'
                +             ' AND   P.Sku = @c_sku'
                +             ' AND   O.Status < ''9'''
                +             ' GROUP BY P.Lot, O.Facility) PR' 
                +             ' ON (LOTxLOCxID.Lot = PR.Lot)'
                +             ' AND (LOC.Facility = PR.Facility)'             
                + ' LEFT JOIN (SELECT Lot, PreAllocatedQty=SUM(Qty) FROM #TMP_PREALLOC WHERE SKU = @c_Sku GROUP BY Lot) PR2 ON PR2.Lot = LOTxLOCxID.Lot'                  
                + ' WHERE SKU.Storerkey = @c_Storerkey'
                + ' AND   SKU.Sku       = @c_Sku'
                + ' AND   LOC.Facility  = @c_Facility'
                + ' AND   (LOC.Pickzone ' 
                + CASE WHEN @c_AgingPickZone = 'YES' AND ISNULL(@n_AgingQtyPerOrd,0) = 0 THEN 'IN (''PMICASEPZ'',''PMICARPZ'',''PMIPACKPZ'',''PMIAGING'') ' ELSE 'IN (''PMICASEPZ'',''PMICARPZ'',''PMIPACKPZ'') ' END  --NJOW01 exclude check aging zone if turn on aging per order
                + ' OR LOC.Loc IN (''PMIRTNSTG'',''PMISTG''))  '
                + @c_AddWhereSQL
                + ' AND   LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked - ISNULL(PR.PreAllocatedQty,0)  - ISNULL(PR2.PreAllocatedQty,0) > 0'
                + ' GROUP BY LOTxLOCxID.Lot) AS T'
            
            SET @c_SQLParms = N'@c_Facility     NVARCHAR(5)'  
                            + ',@c_StorerKey    NVARCHAR(15)'
                            + ',@c_AltSku       NVARCHAR(20)'
                            + ',@c_Sku          NVARCHAR(20)'
                            + ',@c_Lottable01   NVARCHAR(18)'
                            + ',@c_Lottable02   NVARCHAR(18)'
                            + ',@c_Lottable03   NVARCHAR(18)'
                            + ',@dt_Lottable04  DATETIME'
                            + ',@dt_Lottable05  DATETIME'
                            + ',@c_Lottable06   NVARCHAR(30)'
                            + ',@c_Lottable07   NVARCHAR(30)'
                            + ',@c_Lottable08   NVARCHAR(30)'
                            + ',@c_Lottable09   NVARCHAR(30)'
                            + ',@c_Lottable10   NVARCHAR(30)'
                            + ',@c_Lottable11   NVARCHAR(30)'
                            + ',@c_Lottable12   NVARCHAR(30)'
                            + ',@dt_Lottable13  DATETIME'
                            + ',@dt_Lottable14  DATETIME'
                            + ',@dt_Lottable15  DATETIME'
                            + ',@c_PickZone     NVARCHAR(10)'
                            + ',@n_QtyAvailable INT OUTPUT '
            
            EXEC sp_executesql @c_SQL                                                                                   
               ,@c_SQLParms     
               ,@c_Facility                                                                                                  
               ,@c_StorerKey   
               ,@c_AltSku   
               ,@c_Sku   
               ,@c_Lottable01                                                                                          
     	         ,@c_Lottable02
               ,@c_Lottable03
               ,@dt_Lottable04  
               ,@dt_Lottable05 
               ,@c_Lottable06                                                                                         
     	         ,@c_Lottable07
               ,@c_Lottable08
               ,@c_Lottable09  
               ,@c_Lottable10  
               ,@c_Lottable11                                                                                          
     	         ,@c_Lottable12   
               ,@dt_Lottable13
               ,@dt_Lottable14  
               ,@dt_Lottable15  
               ,@c_PickZone              
               ,@n_QtyAvailable OUTPUT                            
               
            IF @n_QtyAvailable > 0
               GOTO NEXT_ALTSKU           	         	
         END
                  
         NEXT_SKU:         
      END --sku loop
      
      NEXT_ALTSKU:

      FETCH NEXT FROM CUR_OD INTO  @c_Facility
                                 , @c_Storerkey
                                 , @c_AltSku
                                 , @c_Lottable01     
                                 , @c_Lottable02     
                                 , @c_Lottable03     
                                 , @dt_Lottable04    
                                 , @dt_Lottable05    
                                 , @c_Lottable06     
                                 , @c_Lottable07     
                                 , @c_Lottable08     
                                 , @c_Lottable09     
                                 , @c_Lottable10     
                                 , @c_Lottable11     
                                 , @c_Lottable12     
                                 , @dt_Lottable13    
                                 , @dt_Lottable14    
                                 , @dt_Lottable15  
                                 , @n_QtyLeftToFulfill  
                                 , @c_ConsigneeKey                                                 --(Wan01)                                                                                                   
   END --Order altsku loop
   CLOSE CUR_OD
   DEALLOCATE CUR_OD  

   BEGIN TRAN         
   SET @c_AltSku_Prev = ''
   DECLARE CUR_SPLIT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT  Sku
         , AltSku
         , Lottable01     
         , Lottable02     
         , Lottable03     
         , Lottable04    
         , Lottable05    
         , Lottable06     
         , Lottable07     
         , Lottable08     
         , Lottable09     
         , Lottable10     
         , Lottable11     
         , Lottable12     
         , Lottable13    
         , Lottable14    
         , Lottable15 
         , Qty = Sum(Qty)
         , QtyLeftToFulfill
   FROM #TMP_PREALLOC 
   GROUP BY Sku
          , AltSku
          , Lottable01     
          , Lottable02     
          , Lottable03     
          , Lottable04    
          , Lottable05    
          , Lottable06     
          , Lottable07     
          , Lottable08     
          , Lottable09     
          , Lottable10     
          , Lottable11     
          , Lottable12     
          , Lottable13    
          , Lottable14    
          , Lottable15 
          , QtyLeftToFulfill
   ORDER BY --, MIN(RowRef)                                                                        --(Wan01)
            AltSku
          , Lottable01     
          , Lottable02     
          , Lottable03     
          , Lottable04    
          , Lottable05    
          , Lottable06     
          , Lottable07     
          , Lottable08     
          , Lottable09     
          , Lottable10     
          , Lottable11     
          , Lottable12     
          , Lottable13    
          , Lottable14    
          , Lottable15
               
   OPEN CUR_SPLIT
   
   FETCH NEXT FROM CUR_SPLIT INTO  @c_Sku
                                 , @c_AltSku
                                 , @c_Lottable01     
                                 , @c_Lottable02     
                                 , @c_Lottable03     
                                 , @dt_Lottable04    
                                 , @dt_Lottable05    
                                 , @c_Lottable06     
                                 , @c_Lottable07     
                                 , @c_Lottable08     
                                 , @c_Lottable09     
                                 , @c_Lottable10     
                                 , @c_Lottable11     
                                 , @c_Lottable12     
                                 , @dt_Lottable13    
                                 , @dt_Lottable14    
                                 , @dt_Lottable15 
                                 , @n_OpenQty
                                 , @n_QtyLeftToFulfill
   
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      IF @c_AltSku_Prev <> @c_AltSku 
      OR @c_Lottable01_Prev  <> @c_Lottable01    
      OR @c_Lottable02_Prev  <> @c_Lottable02    
      OR @c_Lottable03_Prev  <> @c_Lottable03    
      OR @dt_Lottable04_Prev <> @dt_Lottable04   
      OR @dt_Lottable05_Prev <> @dt_Lottable05   
      OR @c_Lottable06_Prev  <> @c_Lottable06    
      OR @c_Lottable07_Prev  <> @c_Lottable07    
      OR @c_Lottable08_Prev  <> @c_Lottable08    
      OR @c_Lottable09_Prev  <> @c_Lottable09    
      OR @c_Lottable10_Prev  <> @c_Lottable10    
      OR @c_Lottable11_Prev  <> @c_Lottable11    
      OR @c_Lottable12_Prev  <> @c_Lottable12    
      OR @dt_Lottable13_Prev <> @dt_Lottable13   
      OR @dt_Lottable14_Prev <> @dt_Lottable14   
      OR @dt_Lottable15_Prev <> @dt_Lottable15   
      BEGIN
         SET @n_OpenQty = @n_OpenQty + @n_QtyLeftToFulfill

         --Fix NJOW03
         DECLARE CUR_ORDLINE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
            SELECT OD.OrderLineNumber, OD.QtyAllocated + OD.QtyPicked + OD.QtyPreAllocated + ISNULL(AL.ALQty,0) AS OpenQty
            FROM ORDERDETAIL OD WITH (NOLOCK)
            OUTER APPLY (SELECT SUM (TL.Qty) AS ALQty
                         FROM  #TMP_PREALLOC TL WITH (NOLOCK) 
                         WHERE TL.Orderkey = OD.Orderkey
                         AND   TL.ALTSku   = OD.AltSku
                         AND   TL.Sku      = OD.Sku
                         AND   TL.Lottable01 = @c_Lottable01
                         AND   TL.Lottable02 = @c_Lottable02
                         AND   TL.Lottable03 = @c_Lottable03
                         AND   TL.Lottable04 = @dt_Lottable04
                         AND   TL.Lottable05 = @dt_Lottable05
                         AND   TL.Lottable06 = @c_Lottable06
                         AND   TL.Lottable07 = @c_Lottable07
                         AND   TL.Lottable08 = @c_Lottable08
                         AND   TL.Lottable09 = @c_Lottable09
                         AND   TL.Lottable10 = @c_Lottable10
                         AND   TL.Lottable11 = @c_Lottable11
                         AND   TL.Lottable12 = @c_Lottable12
                         AND   TL.Lottable13 = @dt_Lottable13
                         AND   TL.Lottable14 = @dt_Lottable14
                         AND   TL.Lottable15 = @dt_Lottable15) AL
            WHERE OD.Orderkey = @c_Orderkey
            AND   OD.Storerkey= @c_Storerkey
            AND   OD.AltSku   = @c_AltSku
            AND   OD.Lottable01 = @c_Lottable01
            AND   OD.Lottable02 = @c_Lottable02
            AND   OD.Lottable03 = @c_Lottable03
            AND   ISNULL(OD.Lottable04,'19000101') = @dt_Lottable04
            AND   ISNULL(OD.Lottable05,'19000101') = @dt_Lottable05
            AND   OD.Lottable06 = @c_Lottable06
            AND   OD.Lottable07 = @c_Lottable07
            AND   OD.Lottable08 = @c_Lottable08
            AND   OD.Lottable09 = @c_Lottable09
            AND   OD.Lottable10 = @c_Lottable10
            AND   OD.Lottable11 = @c_Lottable11
            AND   OD.Lottable12 = @c_Lottable12
            AND   ISNULL(OD.Lottable13,'19000101') = @dt_Lottable13
            AND   ISNULL(OD.Lottable14,'19000101') = @dt_Lottable14
            AND   ISNULL(OD.Lottable15,'19000101') = @dt_Lottable15
            AND   OD.QtyAllocated + OD.QtyPicked + OD.QtyPreAllocated + ISNULL(AL.ALQty,0) <> OD.OpenQty
            
            OPEN CUR_ORDLINE  
            
            FETCH NEXT FROM CUR_ORDLINE INTO @c_OrderLineNumber, @n_NewOpenQty  
            
            WHILE @@FETCH_STATUS <> -1 AND @n_continue IN(1,2)
            BEGIN            	
               UPDATE ORDERDETAIL WITH (ROWLOCK)
               SET OpenQty = @n_NewOpenQty
                  ,OriginalQty = @n_NewOpenQty
                  ,EditDate= GETDATE()
                  ,EditWho = SUSER_NAME()
               WHERE Orderkey = @c_Orderkey
               AND OrderLineNumber = @c_OrderLineNumber 

               IF @@ERROR <> 0 
               BEGIN
                  SET @n_Continue = 3    
                  SET @n_Err = 63515    
                  SET @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Update Failed On Table ORDERDETAIL. (ispPreAL04)'
               END
               
               FETCH NEXT FROM CUR_ORDLINE INTO @c_OrderLineNumber, @n_NewOpenQty              	
            END
            CLOSE CUR_ORDLINE
            DEALLOCATE CUR_ORDLINE                    
      END

      IF @b_debug = 1
      BEGIN
         SELECT @n_QtyLeftToFulfill 'QtyLeftToFulfill',@n_OpenQty 'OpenQty' 
      END

      SET @c_Packkey = ''
      SET @c_UOM = ''

      SELECT @c_Packkey = SKU.Packkey
            ,@c_UOM     = PACK.PackUOM3
      FROM SKU  WITH (NOLOCK) 
      JOIN PACK WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
      WHERE Storerkey = @c_Storerkey
      AND   Sku = @c_Sku

      -- Same AltSku and Sku OrderlineNumber
      SET @c_OrderLineNumber = ''
      SELECT @c_OrderLineNumber = OrderLineNumber
      FROM ORDERDETAIL WITH (NOLOCK)
      WHERE Orderkey = @c_Orderkey
      AND   Storerkey= @c_Storerkey
      AND   Sku      = @c_Sku
      AND   AltSku   = @c_AltSku
      AND   Lottable01 = @c_Lottable01
      AND   Lottable02 = @c_Lottable02
      AND   Lottable03 = @c_Lottable03
      AND   ISNULL(Lottable04,'19000101') = @dt_Lottable04
      AND   ISNULL(Lottable05,'19000101') = @dt_Lottable05
      AND   Lottable06 = @c_Lottable06
      AND   Lottable07 = @c_Lottable07
      AND   Lottable08 = @c_Lottable08
      AND   Lottable09 = @c_Lottable09
      AND   Lottable10 = @c_Lottable10
      AND   Lottable11 = @c_Lottable11
      AND   Lottable12 = @c_Lottable12
      AND   ISNULL(Lottable13,'19000101') = @dt_Lottable13
      AND   ISNULL(Lottable14,'19000101') = @dt_Lottable14
      AND   ISNULL(Lottable15,'19000101') = @dt_Lottable15

      IF @c_OrderLineNumber = ''
      BEGIN
         -- Find Open OrderlineNumber with Same AltSku 
         SELECT TOP 1 @c_OrderLineNumber = OrderLineNumber
         FROM ORDERDETAIL WITH (NOLOCK)
         WHERE Orderkey = @c_Orderkey
         AND   Storerkey= @c_Storerkey
         AND   AltSku   = @c_AltSku
         AND   Lottable01 = @c_Lottable01
         AND   Lottable02 = @c_Lottable02
         AND   Lottable03 = @c_Lottable03
         AND   ISNULL(Lottable04,'19000101') = @dt_Lottable04
         AND   ISNULL(Lottable05,'19000101') = @dt_Lottable05
         AND   Lottable06 = @c_Lottable06
         AND   Lottable07 = @c_Lottable07
         AND   Lottable08 = @c_Lottable08
         AND   Lottable09 = @c_Lottable09
         AND   Lottable10 = @c_Lottable10
         AND   Lottable11 = @c_Lottable11
         AND   Lottable12 = @c_Lottable12
         AND   ISNULL(Lottable13,'19000101') = @dt_Lottable13
         AND   ISNULL(Lottable14,'19000101') = @dt_Lottable14
         AND   ISNULL(Lottable15,'19000101') = @dt_Lottable15
         AND   Sku      <> @c_Sku
         AND   QtyAllocated + QtyPicked + QtyPreAllocated = 0
      END
      
      IF @c_OrderLineNumber <> ''
      BEGIN
         UPDATE ORDERDETAIL WITH (ROWLOCK)
            SET Sku     = @c_Sku
               ,PackKey = @c_Packkey
               ,UOM     = @c_UOM 
               ,OpenQty = QtyAllocated + QtyPicked + QtyPreAllocated + @n_OpenQty
               ,OriginalQty = QtyAllocated + QtyPicked + QtyPreAllocated + @n_OpenQty --fix NJOW03               
               ,EditDate= GETDATE()
               ,EditWho = SUSER_NAME()
         WHERE Orderkey = @c_Orderkey
         AND OrderLineNumber = @c_OrderLineNumber 

         IF @@ERROR <> 0 
         BEGIN
            SET @n_Continue = 3    
            SET @n_Err = 63530    
            SET @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Update Failed On Table ORDERDETAIL. (ispPreAL04)'
            GOTO QUIT_SP  
         END
      END
      ELSE
      BEGIN
         SELECT @c_OrderLineNumber = RIGHT('00000' + CONVERT(VARCHAR(5), MAX(OrderLineNumber) + 1),5)
         FROM ORDERDETAIL WITH (NOLOCK)
         WHERE Orderkey = @c_Orderkey

         INSERT INTO ORDERDETAIL  
            (
               Orderkey
            ,  OrderLineNumber
            ,  Storerkey
            ,  Sku
            ,  ManufacturerSku
            ,  RetailSku
            ,  AltSku
            ,  OriginalQty
            ,  OpenQty
            ,  Packkey
            ,  UOM 
            ,  PickCode
            ,  CartonGroup
            ,  Facility
            ,  UnitPrice
            ,  Tax01
            ,  Tax02
            ,  ExtendedPrice
            ,  Lottable01
            ,  Lottable02
            ,  Lottable03
            ,  Lottable04
            ,  Lottable05
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
            ,  FreeGoodQty
            ,  UserDefine01
            ,  UserDefine02
            ,  UserDefine03
            ,  UserDefine04
            ,  UserDefine05
            ,  UserDefine06
            ,  UserDefine07
            ,  UserDefine08
            ,  UserDefine09
            ,  UserDefine10
            ,  Loadkey
            )
         SELECT TOP 1
               Orderkey
            ,  @c_OrderLineNumber
            ,  @c_Storerkey
            ,  @c_Sku
            ,  ManufacturerSku
            ,  RetailSku
            ,  AltSku
            ,  @n_OpenQty
            ,  @n_OpenQty
            ,  @c_Packkey
            ,  @c_UOM 
            ,  PickCode
            ,  CartonGroup
            ,  Facility
            ,  UnitPrice
            ,  Tax01
            ,  Tax02
            ,  ExtendedPrice
            ,  Lottable01
            ,  Lottable02
            ,  Lottable03
            ,  Lottable04
            ,  Lottable05
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
            ,  FreeGoodQty
            ,  UserDefine01
            ,  UserDefine02
            ,  UserDefine03
            ,  UserDefine04
            ,  UserDefine05
            ,  UserDefine06
            ,  UserDefine07
            ,  UserDefine08
            ,  UserDefine09
            ,  UserDefine10
            ,  Loadkey
         FROM ORDERDETAIL WITH (NOLOCK)
         WHERE Orderkey = @c_Orderkey
         AND   AltSku = @c_AltSku
         AND   Lottable01 = @c_Lottable01
         AND   Lottable02 = @c_Lottable02
         AND   Lottable03 = @c_Lottable03
         AND   ISNULL(Lottable04,'19000101') = @dt_Lottable04
         AND   ISNULL(Lottable05,'19000101') = @dt_Lottable05
         AND   Lottable06 = @c_Lottable06
         AND   Lottable07 = @c_Lottable07
         AND   Lottable08 = @c_Lottable08
         AND   Lottable09 = @c_Lottable09
         AND   Lottable10 = @c_Lottable10
         AND   Lottable11 = @c_Lottable11
         AND   Lottable12 = @c_Lottable12
         AND   ISNULL(Lottable13,'19000101') = @dt_Lottable13
         AND   ISNULL(Lottable14,'19000101') = @dt_Lottable14
         AND   ISNULL(Lottable15,'19000101') = @dt_Lottable15

         IF @@ERROR <> 0 
         BEGIN
            SET @n_Continue = 3    
            SET @n_Err = 63540    
            SET @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Insert Failed INTO Table ORDERDETAIL. (ispPreAL04)'
            GOTO QUIT_SP  
         END
         ELSE
         BEGIN
         	  --NJOW03
         	  UPDATE ORDERDETAIL WITH (ROWLOCK)
         	  SET EnteredQTY = 0,
         	      TrafficCop = NULL
         	  WHERE Orderkey = @c_Orderkey
         	  AND OrderLineNumber = @c_OrderLineNumber
         END
      END
      
      DECLARE CUR_PREALLOC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT Lot
            ,Qty 
            ,UOM                                                                                   --(Wan01)
            ,UOMQty                                                                                --(Wan01)
      FROM  #TMP_PREALLOC WITH (NOLOCK) 
      WHERE ORderkey = @c_Orderkey
      AND   ALTSku   = @c_AltSku
      AND   Sku      = @c_Sku 
      AND   Lottable01 = @c_Lottable01
      AND   Lottable02 = @c_Lottable02
      AND   Lottable03 = @c_Lottable03
      AND   Lottable04 = @dt_Lottable04
      AND   Lottable05 = @dt_Lottable05
      AND   Lottable06 = @c_Lottable06
      AND   Lottable07 = @c_Lottable07
      AND   Lottable08 = @c_Lottable08
      AND   Lottable09 = @c_Lottable09
      AND   Lottable10 = @c_Lottable10
      AND   Lottable11 = @c_Lottable11
      AND   Lottable12 = @c_Lottable12
      AND   Lottable13 = @dt_Lottable13
      AND   Lottable14 = @dt_Lottable14
      AND   Lottable15 = @dt_Lottable15
       
      OPEN CUR_PREALLOC
   
      FETCH NEXT FROM CUR_PREALLOC INTO @c_Lot
                                       ,@n_Qty
                                       ,@c_UOM                                                     --(Wan01)  
                                       ,@n_UOMQty                                                  --(Wan01)         
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         SET @b_success = 0
         EXECUTE nspg_getkey 
                 'PreAllocatePickDetailKey'
               , 10
               , @c_PreAllocatePickDetailKey OUTPUT
               , @b_success OUTPUT
               , @n_err OUTPUT
               , @c_errmsg OUTPUT

         IF @b_success <> 1
         BEGIN
            SET @n_Continue = 3    
            SET @n_Err = 63550    
            SET @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Error Getting PreAllocatePickDetailKey. (ispPreAL04)'
            GOTO QUIT_SP 
         END 

         INSERT INTO PREALLOCATEPICKDETAIL
               (  PreAllocatePickDetailKey
               ,  Orderkey
               ,  OrderLineNumber
               ,  Storerkey
               ,  Sku
               ,  Lot
               ,  UOM 
               ,  UOMQty
               ,  Packkey
               ,  Qty
               ,  PreAllocateStrategyKey   
               ,  PreAllocatePickCode
               )
         VALUES ( @c_PreAllocatePickDetailKey
               ,  @c_Orderkey
               ,  @c_OrderLineNumber
               ,  @c_Storerkey
               ,  @c_Sku
               ,  @c_Lot
               ,  @c_UOM                                                                           --(Wan01)  
               ,  @n_UOMQty                                                                        --(Wan01)     
               ,  @c_Packkey
               ,  @n_Qty
               , 'SplitOrdLn'
               , 'ispPreAL04'
               )

         IF @@ERROR <> 0 
         BEGIN
            SET @n_Continue = 3    
            SET @n_Err = 63560    
            SET @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Insert Failed Into Table ORDERDETAIL. (ispPreAL04)'
            GOTO QUIT_SP  
         END 
      
         FETCH NEXT FROM CUR_PREALLOC INTO @c_Lot
                                         , @n_Qty
                                         , @c_UOM                                                  --(Wan01) 
                                         , @n_UOMQty                                               --(Wan01) 
      END 
      CLOSE CUR_PREALLOC
      DEALLOCATE CUR_PREALLOC

      SET @c_AltSku_Prev      = @c_AltSku
      SET @c_Lottable01_Prev  = @c_Lottable01       
      SET @c_Lottable02_Prev  = @c_Lottable02       
      SET @c_Lottable03_Prev  = @c_Lottable03       
      SET @dt_Lottable04_Prev = @dt_Lottable04      
      SET @dt_Lottable05_Prev = @dt_Lottable05      
      SET @c_Lottable06_Prev  = @c_Lottable06       
      SET @c_Lottable07_Prev  = @c_Lottable07       
      SET @c_Lottable08_Prev  = @c_Lottable08       
      SET @c_Lottable09_Prev  = @c_Lottable09       
      SET @c_Lottable10_Prev  = @c_Lottable10       
      SET @c_Lottable11_Prev  = @c_Lottable11       
      SET @c_Lottable12_Prev  = @c_Lottable12       
      SET @dt_Lottable13_Prev = @dt_Lottable13      
      SET @dt_Lottable14_Prev = @dt_Lottable14      
      SET @dt_Lottable15_Prev = @dt_Lottable15      
      FETCH NEXT FROM CUR_SPLIT INTO  @c_Sku, @c_AltSku
                                    , @c_Lottable01     
                                    , @c_Lottable02     
                                    , @c_Lottable03     
                                    , @dt_Lottable04    
                                    , @dt_Lottable05    
                                    , @c_Lottable06     
                                    , @c_Lottable07     
                                    , @c_Lottable08     
                                    , @c_Lottable09     
                                    , @c_Lottable10     
                                    , @c_Lottable11     
                                    , @c_Lottable12     
                                    , @dt_Lottable13    
                                    , @dt_Lottable14    
                                    , @dt_Lottable15 
                                    , @n_OpenQty
                                    , @n_QtyLeftToFulfill
   END 
   CLOSE CUR_SPLIT
   DEALLOCATE CUR_SPLIT

   -- Remove ALTSKu Residual orderdetail line
   DECLARE CUR_OD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT OD.Orderkey
         ,OD.OrderLineNumber
   FROM ORDERDETAIL OD WITH (NOLOCK)  
   JOIN #TMP_PREALLOC  PR ON  (OD.AltSku = PR.AltSku AND OD.Orderkey = PR.Orderkey)
                          AND (OD.Lottable01 = PR.Lottable01)
                          AND (OD.Lottable02 = PR.Lottable02)
                          AND (OD.Lottable03 = PR.Lottable03)
                          AND (ISNULL(OD.Lottable04,'19000101') = PR.Lottable04)
                          AND (ISNULL(OD.Lottable05,'19000101') = PR.Lottable05)
                          AND (OD.Lottable06 = PR.Lottable06)
                          AND (OD.Lottable07 = PR.Lottable07)
                          AND (OD.Lottable08 = PR.Lottable08)
                          AND (OD.Lottable09 = PR.Lottable09)
                          AND (OD.Lottable10 = PR.Lottable10)
                          AND (OD.Lottable11 = PR.Lottable11)
                          AND (OD.Lottable12 = PR.Lottable12)
                          AND (ISNULL(OD.Lottable13,'19000101') = PR.Lottable13)
                          AND (ISNULL(OD.Lottable14,'19000101') = PR.Lottable14)
                          AND (ISNULL(OD.Lottable15,'19000101') = PR.Lottable15)                          
   WHERE OD.Orderkey = @c_Orderkey
   AND   OD.QtyAllocated + OD.QtyPicked + OD.QtyPreAllocated = 0
   AND OD.AltSku <> ''
   OPEN CUR_OD
  
   FETCH NEXT FROM CUR_OD INTO @c_Orderkey
                 , @c_OrderLineNumber
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      DELETE FROM ORDERDETAIL WITH (ROWLOCK)
      WHERE Orderkey = @c_Orderkey
      AND   OrderLineNumber = @c_OrderLineNumber  

      IF @@ERROR <> 0 
      BEGIN
         SET @n_Continue = 3    
         SET @n_Err = 63560    
         SET @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Delete Failed From Table ORDERDETAIL. (ispPreAL04)'
         GOTO QUIT_SP  
      END                  
      FETCH NEXT FROM CUR_OD INTO @c_Orderkey
                                , @c_OrderLineNumber
   END
   CLOSE CUR_OD
   DEALLOCATE CUR_OD
QUIT_SP:

   IF CURSOR_STATUS( 'LOCAL', 'CUR_OD') in (0 , 1)  
   BEGIN
      CLOSE CUR_OD
      DEALLOCATE CUR_OD
   END

   IF CURSOR_STATUS( 'GLOBAL', 'CUR_LLI') in (0 , 1)  
   BEGIN
      CLOSE CUR_LLI
      DEALLOCATE CUR_LLI
   END

   IF CURSOR_STATUS( 'LOCAL', 'CUR_SPLIT') in (0 , 1)  
   BEGIN
      CLOSE CUR_SPLIT
      DEALLOCATE CUR_SPLIT
   END

   IF CURSOR_STATUS( 'LOCAL', 'CUR_PREALLOC') in (0 , 1)  
   BEGIN
      CLOSE CUR_PREALLOC
      DEALLOCATE CUR_PREALLOC
   END

 IF CURSOR_STATUS( 'LOCAL', 'CUR_UOM') in (0 , 1)  
   BEGIN
      CLOSE CUR_UOM
      DEALLOCATE CUR_UOM
   END
   
   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispPreAL04'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
END -- procedure

GO