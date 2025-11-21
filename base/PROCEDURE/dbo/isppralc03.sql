SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure:  ispPRALC03                                        */  
/* Creation Date: 04-DEC-2017                                           */  
/* Copyright: LFL                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose:  WMS-2875 - NIKE CRW Plus Pre Allocation process            */  
/*           set the sp to storerconfig PreAllocationSP                 */
/*                                                                      */  
/* Called By:                                                           */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 1.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author  Rev   Purposes                                  */  
/* 17-Jan-2018  NJOW01  1.0   WMS-2875 Sorting based on codelkup        */
/* 19-Jan-2018  Wan01   1.1   Fixed Group by issue if codelkup not setup*/
/* 15-May-2018  NJOW01  1.2   WMS-3801 Enhancements                     */
/* 09-July-2018	NJOW02  1.3   WMS-5635 zone sorting based on multiple   */
/*                            codelkup by consignee                     */
/* 28-Jul-2021	NJOW03  1.4   WMS-17580 exclude lottable12=INACCESSIBLE */
/************************************************************************/  
CREATE PROC [dbo].[ispPRALC03] (
     @c_OrderKey        NVARCHAR(10)  
   , @c_LoadKey         NVARCHAR(10)    
   , @b_Success         INT           OUTPUT    
   , @n_Err             INT           OUTPUT    
   , @c_ErrMsg          NVARCHAR(250) OUTPUT    
   , @b_debug           INT = 0 )
AS 
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue    INT,  
           @n_StartTCnt   INT

   SELECT @n_StartTCnt = @@TRANCOUNT , @n_Continue=1, @b_Success=1, @n_Err=0, @c_ErrMsg=''

   DECLARE @c_OrderLineNumber        NVARCHAR(5)
          ,@c_SKU                    NVARCHAR(20)
          ,@c_StorerKey              NVARCHAR(15)
          ,@n_OpenQty                INT
          ,@c_UOM                    NVARCHAR(10)           
          ,@c_Lottable01             NVARCHAR(18)              
          ,@c_Lottable02             NVARCHAR(18)
          ,@c_Lottable03             NVARCHAR(18)              
          ,@d_Lottable04             DATETIME                  
          ,@d_Lottable05             DATETIME
          ,@c_Lottable06             NVARCHAR(30)              
          ,@c_Lottable07             NVARCHAR(30)
          ,@c_Lottable08             NVARCHAR(30)              
          ,@c_Lottable09             NVARCHAR(30)
          ,@c_Lottable10             NVARCHAR(30)              
          ,@c_Lottable11             NVARCHAR(30)
          ,@c_Lottable12             NVARCHAR(30)
          ,@d_Lottable13             DATETIME                  
          ,@d_Lottable14             DATETIME
          ,@d_Lottable15             DATETIME                            
          ,@c_Lottable04             NVARCHAR(30)
          ,@c_Lottable05             NVARCHAR(30)             
          ,@c_Lottable13             NVARCHAR(30)
          ,@c_Lottable14             NVARCHAR(30)             
          ,@c_Lottable15             NVARCHAR(30)
          ,@c_Lot                    NVARCHAR(10)
          ,@c_Facility               NVARCHAR(5)
          ,@c_PackKey                NVARCHAR(10)          
          ,@n_CaseCnt                INT    
          ,@c_LimitString            NVARCHAR(4000) = ''
          ,@c_SQL                    NVARCHAR(MAX) = ''   
          ,@c_SQLParm                NVARCHAR(MAX) = ''
          ,@n_MazzanineB_Qty         INT = 0  
          ,@n_MazzanineS_Qty         INT = 0
          ,@n_HB_Qty                 INT = 0 
          ,@n_Pack_MezzineB          INT = 0 
   	      ,@n_Pack_MezzineS          INT = 0
   	      ,@n_Pack_HB                INT = 0
   	      ,@c_LOC                    NVARCHAR(10)
   	      ,@c_LOC_A                  NVARCHAR(10)
   	      ,@c_LOC_B                  NVARCHAR(10) 
   	      ,@n_LOC_A_Qty              INT = 0
   	      ,@n_LOC_B_Qty              INT = 0
   	      ,@n_Qty                    INT = 0
   	      ,@n_AllocSeq               INT = 0   
          ,@n_QtyAllocated           INT = 0
          ,@c_ID                     NVARCHAR(18) 
          ,@n_QtyLeftToFulfill       INT
          ,@c_PickDetailKey          NVARCHAR(10)
          --,@c_CaseCond               NVARCHAR(2000) --NJOW01
          ,@c_PickSeq                NVARCHAR(10) --NJOW01
          ,@c_Consigneekey           NVARCHAR(15) --NJOW02
          ,@c_B_State                NVARCHAR(45) --NJOW02
          ,@c_Country                NVARCHAR(30) --NJOW02
          ,@c_ListName               NVARCHAR(10) --NJOW02
          
   SET @c_UOM = '6'       
      	                                                          
   IF OBJECT_ID('tempdb..#LOCSeq') IS NOT NULL
      DROP TABLE #LOCSeq
      
   CREATE TABLE #LOCSeq (LOC               NVARCHAR(10),
   	                     LocationCategory  NVARCHAR(10),
   	                     AllocSeq          INT,  
   	                     QtyAvailable      INT,
   	                     QtyAllocated      INT,
   	                     PickZone          NVARCHAR(10)) --NJOW01
   	                     --ZoneSeq           NVARCHAR(10))  --NJOW01
   
   IF ISNULL(@c_Orderkey,'') <> ''
   BEGIN 
      DECLARE CUR_ORDER_LINES CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT OD.StorerKey, OD.OrderKey, OD.OrderLineNumber, OD.Sku, (OD.OpenQty - (OD.QtyAllocated + OD.QtyPicked))
                     ,SKU.Packkey
                     ,PACK.CaseCnt
                     ,OD.LOTTABLE01
                     ,OD.LOTTABLE02
                     ,OD.LOTTABLE03
                     ,OD.LOTTABLE04
                     ,OD.LOTTABLE05
                     ,OD.LOTTABLE06
                     ,OD.LOTTABLE07
                     ,OD.LOTTABLE08
                     ,OD.LOTTABLE09
                     ,OD.LOTTABLE10
                     ,OD.LOTTABLE11
                     ,OD.LOTTABLE12
                     ,OD.LOTTABLE13
                     ,OD.LOTTABLE14
                     ,OD.LOTTABLE15
                     ,O.Facility
                     ,O.Consigneekey --NJOW02
                     ,ISNULL(CONS.B_State,'') --NJOW02
                     ,ISNULL(CONS.Country,'') --NJOW02
      FROM ORDERS AS o WITH (NOLOCK) 
      JOIN ORDERDETAIL AS OD WITH (NOLOCK) ON OD.OrderKey = o.OrderKey  	 
      JOIN SKU WITH (NOLOCK) ON OD.Storerkey = SKU.Storerkey AND OD.Sku = SKU.Sku
      JOIN PACK WITH (NOLOCK) ON SKU.Packkey = PACK.Packkey
      LEFT OUTER JOIN STORER CONS WITH (NOLOCK) ON o.Consigneekey = CONS.Storerkey  --NJOW02
      LEFT OUTER JOIN LoadPlanDetail LPD WITH (NOLOCK) ON o.OrderKey = LPD.OrderKey 
      WHERE o.OrderKey = @c_OrderKey  
      AND (OD.OpenQty - (OD.QtyAllocated + OD.QtyPicked)) > 0 
      --AND NOT EXISTS(SELECT 1
      --               FROM ORDERDETAIL (NOLOCK)
      --               JOIN CODELKUP (NOLOCK) ON ORDERDETAIL.Lottable11 = SUBSTRING(CODELKUP.Code,3,1) 
      --                                     AND CODELKUP.Listname ='NONSTKITF' AND CODELKUP.Long = 'NIKECN'
      --               WHERE ORDERDETAIL.Orderkey = o.Orderkey) --NJOW02
      --AND OD.Lottable02 = '01RTN'  --NJOW01
      ORDER BY OD.Orderkey, OD.OrderLineNumber 
   END          
   ELSE IF ISNULL(@c_Loadkey,'') <> ''
   BEGIN
      DECLARE CUR_ORDER_LINES CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT OD.StorerKey, OD.OrderKey, OD.OrderLineNumber, OD.Sku, (OD.OpenQty - (OD.QtyAllocated + OD.QtyPicked))
                     ,SKU.Packkey
                     ,PACK.CaseCnt
                     ,OD.LOTTABLE01
                     ,OD.LOTTABLE02
                     ,OD.LOTTABLE03
                     ,OD.LOTTABLE04
                     ,OD.LOTTABLE05
                     ,OD.LOTTABLE06
                     ,OD.LOTTABLE07
                     ,OD.LOTTABLE08
                     ,OD.LOTTABLE09
                     ,OD.LOTTABLE10
                     ,OD.LOTTABLE11
                     ,OD.LOTTABLE12
                     ,OD.LOTTABLE13
                     ,OD.LOTTABLE14
                     ,OD.LOTTABLE15
                     ,O.Facility
                     ,O.Consigneekey --NJOW02
                     ,ISNULL(CONS.B_State,'') --NJOW02
                     ,ISNULL(CONS.Country,'') --NJOW02
      FROM ORDERS AS o WITH (NOLOCK) 
      JOIN ORDERDETAIL AS OD WITH (NOLOCK) ON OD.OrderKey = o.OrderKey  	 
      JOIN SKU WITH (NOLOCK) ON OD.Storerkey = SKU.Storerkey AND OD.Sku = SKU.Sku
      JOIN PACK WITH (NOLOCK) ON SKU.Packkey = PACK.Packkey
      LEFT OUTER JOIN STORER CONS WITH (NOLOCK) ON o.Consigneekey = CONS.Storerkey  --NJOW02
      LEFT OUTER JOIN LoadPlanDetail LPD WITH (NOLOCK) ON o.OrderKey = LPD.OrderKey 
      WHERE LPD.LoadKey = @c_Loadkey 
      --AND  ( LPD.LoadKey = CASE WHEN ISNULL(RTRIM(@c_LoadKey),'') = '' THEN LPD.LoadKey ELSE @c_LoadKey END OR 
      --       ( LPD.LoadKey IS NULL AND ISNULL(RTRIM(@c_LoadKey),'') = '' ) ) 
      AND (OD.OpenQty - (OD.QtyAllocated + OD.QtyPicked)) > 0 
      --AND NOT EXISTS(SELECT 1
      --               FROM ORDERDETAIL (NOLOCK)
      --               JOIN CODELKUP (NOLOCK) ON ORDERDETAIL.Lottable11 = SUBSTRING(CODELKUP.Code,3,1) 
      --                                     AND CODELKUP.Listname ='NONSTKITF' AND CODELKUP.Long = 'NIKECN'
      --               WHERE ORDERDETAIL.Orderkey = o.Orderkey) --NJOW02
      --AND OD.Lottable02 = '01RTN'  --NJOW01
      ORDER BY OD.Orderkey, OD.OrderLineNumber 
   END
   
   OPEN CUR_ORDER_LINES
   
   FETCH FROM CUR_ORDER_LINES INTO @c_StorerKey, @c_OrderKey, @c_OrderLineNumber, @c_SKU, @n_OpenQty, @c_Packkey, @n_CaseCnt,
                                   @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05, @c_Lottable06, @c_Lottable07, @c_Lottable08, 
                                   @c_Lottable09, @c_Lottable10, @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15, @c_Facility,
                                   @c_Consigneekey, @c_B_State, @c_Country --NJOW02                                                      
      
   WHILE @@FETCH_STATUS = 0 AND @n_Continue IN(1,2)
   BEGIN   	   	                                       
   	  SET @n_QtyLeftToFulfill = @n_OpenQty
   	  SET @c_SQL = ''
   	  SET @c_LimitString = ''
   	  
      IF @d_Lottable04='1900-01-01'  
      BEGIN  
         SELECT @d_Lottable04 = NULL  
      END    
        
      IF @d_Lottable05='1900-01-01'  
      BEGIN  
          SELECT @d_Lottable05 = NULL  
      END    
      
      IF @d_Lottable13='1900-01-01'  
      BEGIN  
          SELECT @d_Lottable13= NULL  
      END    
      
      IF @d_Lottable14='1900-01-01'  
      BEGIN  
          SELECT @d_Lottable14 = NULL  
      END    
      
      IF @d_Lottable15='1900-01-01'  
      BEGIN  
          SELECT @d_Lottable15 = NULL  
      END    
                                     
      IF ISNULL(RTRIM(@c_Lottable01) ,'')<>''  
          SELECT @c_LimitString = RTrim(@c_LimitString)+  
                 ' AND Lottable01= LTrim(RTrim(@c_Lottable01)) '
        
      IF ISNULL(RTRIM(@c_Lottable02) ,'')<>''  
          SELECT @c_LimitString = RTrim(@c_LimitString)+  
                 ' AND Lottable02= LTrim(RTrim(@c_Lottable02)) '
      
      IF ISNULL(RTRIM(@c_Lottable03) ,'')<>''  
          SELECT @c_LimitString = RTrim(@c_LimitString)+  
                 ' AND Lottable03= LTrim(RTrim(@c_Lottable03)) '
        
      IF CONVERT(NVARCHAR(10), @d_Lottable04, 103) <> '01/01/1900' AND @d_Lottable04 IS NOT NULL
            SELECT @c_LimitString = RTRIM(@c_LimitString) + ' AND LOTTABLE04 = @d_Lottable04 '
      
      
      IF CONVERT(NVARCHAR(10), @d_Lottable05, 103) <> '01/01/1900' AND @d_Lottable05 IS NOT NULL
            SELECT @c_LimitString = RTRIM(@c_LimitString) + ' AND LOTTABLE05 = @d_Lottable05 '
      
      IF ISNULL(RTRIM(@c_Lottable06) ,'')<>''  
          SELECT @c_LimitString = RTrim(@c_LimitString)+  
                 ' AND Lottable06= LTrim(RTrim(@c_Lottable06)) '
      
      IF ISNULL(RTRIM(@c_Lottable07) ,'')<>''  
          SELECT @c_LimitString = RTrim(@c_LimitString)+  
                 ' AND Lottable07= LTrim(RTrim(@c_Lottable07)) '
      
      IF ISNULL(RTRIM(@c_Lottable08) ,'')<>''  
          SELECT @c_LimitString = RTrim(@c_LimitString)+  
                 ' AND Lottable08= LTrim(RTrim(@c_Lottable08)) '
      
      IF ISNULL(RTRIM(@c_Lottable09) ,'')<>''  
          SELECT @c_LimitString = RTrim(@c_LimitString)+  
                 ' AND Lottable09= LTrim(RTrim(@c_Lottable09)) '
                 
      IF ISNULL(RTRIM(@c_Lottable10) ,'')<>''  
          SELECT @c_LimitString = RTrim(@c_LimitString)+  
                 ' AND Lottable10= LTrim(RTrim(@c_Lottable10)) '
                 
      IF ISNULL(RTRIM(@c_Lottable11) ,'')<>''  
          SELECT @c_LimitString = RTrim(@c_LimitString)+  
                 ' AND Lottable11= LTrim(RTrim(@c_Lottable11)) '
                 
      IF ISNULL(RTRIM(@c_Lottable12) ,'')<>''  
          SELECT @c_LimitString = RTrim(@c_LimitString)+  
                 ' AND Lottable12= LTrim(RTrim(@c_Lottable12)) '
      
      IF CONVERT(NVARCHAR(10), @d_Lottable13, 103) <> '01/01/1900' AND @d_Lottable13 IS NOT NULL
            SELECT @c_LimitString = RTRIM(@c_LimitString) + ' AND LOTTABLE13 = @d_Lottable13 '
      
      IF CONVERT(NVARCHAR(10), @d_Lottable14, 103) <> '01/01/1900' AND @d_Lottable14 IS NOT NULL
            SELECT @c_LimitString = RTRIM(@c_LimitString) + ' AND LOTTABLE14 = @d_Lottable14 '
      
      IF CONVERT(NVARCHAR(10), @d_Lottable15, 103) <> '01/01/1900' AND @d_Lottable15 IS NOT NULL
            SELECT @c_LimitString = RTRIM(@c_LimitString) + ' AND LOTTABLE15 = @d_Lottable15 '
            
      SELECT @c_LimitString = RTRIM(@c_LimitString) + ' AND NOT EXISTS(SELECT 1 FROM CODELKUP (NOLOCK) WHERE SUBSTRING(CODELKUP.Code,3,1) = LOTATTRIBUTE.Lottable11 ' +
                                                      ' AND CODELKUP.Listname =''NONSTKITF'' AND CODELKUP.Long = ''NIKECN'') ' --NJOW02
                                                      
      SELECT @c_LimitString = RTRIM(@c_LimitString) + ' AND Lottable12 <> ''INACCESSIBLE'' '  --NJOW03                                                
      
      /*
      --NJOW01 Start         		
      SET @c_CaseCond = ' CASE LOC.PickZone '
      SELECT @c_casecond = @c_casecond +' WHEN ''' + RTRIM(code2) + ''' THEN ' + Short --CAST(ROW_NUMBER() OVER(ORDER BY Short) AS NVARCHAR)  
      FROM CODELKUP(NOLOCK) 
      WHERE Listname = 'ALLSORTING'
      AND Storerkey = @c_Storerkey
      ORDER BY Short, long
      
      IF @@ROWCOUNT > 0
         SET @c_casecond = @c_casecond + ' ELSE ''9999'' END '
      ELSE      			       	   			          
   		   SET @c_Casecond  = '0' 
   	  --NJOW01 End	   
   	  */
   	     	  
   	  --NJOW02
      IF EXISTS(SELECT 1
                FROM CODELIST C (NOLOCK) 
                JOIN CODELKUP CL(NOLOCK) ON C.ListName = CL.ListName
                WHERE C.ListGroup = 'NKCN')
      BEGIN          
         DECLARE CUR_PICKSEQ CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   	           SELECT CL.Short AS PickSeq, MIN(C.ListName) AS ListName   	                     	                  
               FROM CODELIST C (NOLOCK) 
               JOIN CODELKUP CL(NOLOCK) ON C.ListName = CL.ListName
               WHERE C.ListGroup = 'NKCN'
               AND LEFT(C.UDF01,4) = LEFT(@c_Consigneekey,4)
               AND (C.UDF02 = @c_Country OR (LEFT(C.UDF02,1) = '!' AND SUBSTRING(C.UDF02,2,30) <> @c_Country) )  
               AND (EXISTS(SELECT 1
                          FROM CODELKUP (NOLOCK) 
                          WHERE Listname = 'NKCNDGcsn'
                          AND Code = @c_Consigneekey) OR ISNULL(C.UDF03,'') <> 'NKCNDGcsn')
               AND (NOT EXISTS(SELECT 1
                          FROM CODELKUP (NOLOCK) 
                          WHERE Listname = 'XNKCNDGcsn'
                          AND Code = @c_Consigneekey) OR ISNULL(C.UDF03,'') <> 'XNKCNDGcsn')
               AND (C.UDF04 = @c_B_State OR ISNULL(C.UDF04,'') = '')
   	           GROUP BY CL.Short
               ORDER BY CL.Short
   	  END   	  
      ELSE 
      BEGIN
   	     --NJOW01   	  
         IF EXISTS(SELECT 1
                   FROM CODELKUP CL(NOLOCK)
                   WHERE CL.Listname = 'ALLSORTING'
                   AND CL.Storerkey = @c_Storerkey)
         BEGIN 	  
   	        DECLARE CUR_PICKSEQ CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   	           SELECT CL.Short AS PickSeq, 
   	                 MIN(CL.ListName) AS ListName --NJOW02
               FROM CODELKUP CL(NOLOCK)
               WHERE CL.Listname = 'ALLSORTING'
               AND CL.Storerkey = @c_Storerkey
   	           GROUP BY CL.Short
               ORDER BY CL.Short
         END
         ELSE
   	        DECLARE CUR_PICKSEQ CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
               SELECT '' AS PickSeq, '' AS ListName --NJOW02      	
      END     

      OPEN CUR_PICKSEQ
      
      FETCH FROM CUR_PICKSEQ INTO @c_PickSeq, @c_ListName --NJOW02                                            
         
      WHILE @@FETCH_STATUS = 0 AND @n_Continue IN(1,2)  --NJOW01
      BEGIN   	   	                                          	     		   		   		   		                                                                      
         SELECT @c_SQL =      
                  +' SELECT LOTxLOCxID.Loc, '
                  + 'LocCategory = CASE WHEN LOC.LocationCategory IN (''MEZZANINEB'',''MEZZANINES'') THEN LOC.LocationCategory '
                  + '  WHEN LOC.PutawayZone = ''HB'' THEN ''HB'' ELSE '''' END ' 
                  +', 0, '
                  +' SUM(CASE WHEN (LOT.Qty - LOT.QtyAllocated - LOT.QtyPicked - LOT.QtyPreAllocated) <  (LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked) '
                  +' THEN (LOT.Qty - LOT.QtyAllocated - LOT.QtyPicked - LOT.QtyPreAllocated) ' + 
                  +' ELSE (LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked) ' + 
                  +' END) AS QtyAvailable, 0, ' + 
                  +' LOC.Pickzone ' +  --NJOW01                  
                  --+ @c_CaseCond +  --NJOW01
                  +' FROM LOT (NOLOCK) '  
                  +' JOIN LOTATTRIBUTE (NOLOCK) ON (lot.lot = lotattribute.lot) '   
                  +' JOIN LOTxLOCxID (NOLOCK) ON (LOTxLOCxID.LOT = LOT.LOT AND LOTxLOCxID.LOT = LOTATTRIBUTE.LOT) '   
                  +' JOIN LOC (NOLOCK) ON (LOTxLOCxID.LOC = LOC.LOC) '  
                  +' JOIN ID (NOLOCK) ON (LOTxLOCxID.ID = ID.ID) ' 
                  +' JOIN SKUxLOC (NOLOCK) ON (SKUxLOC.SKU = LOTxLOCxID.SKU AND SKUxLOC.LOC = LOTxLOCxID.LOC AND SKUxLOC.StorerKey = LOTxLOCxID.StorerKey) '   
                  +  CASE WHEN ISNULL(@c_PickSeq,'') <> '' THEN ' JOIN CODELKUP CL (NOLOCK) ON CL.Listname = @c_ListName AND CL.Storerkey = @c_Storerkey AND CL.Code2 = LOC.PickZone AND CL.Short = @c_PickSeq ' ELSE ' ' END --NJOW01
                  +' WHERE LOTxLOCxID.StorerKey = @c_StorerKey  '  
                  +' AND LOTxLOCxID.SKU = @c_SKU ' 
                  +' AND LOT.STATUS = ''OK'' AND LOC.STATUS <> ''HOLD'' AND ID.STATUS = ''OK'' And LOC.LocationFlag = ''NONE'' '    
                  +' AND LOC.Facility = @c_Facility ' + @c_LimitString + ' '     
                  +' AND (SKUxLOC.LocationType NOT IN (''CASE'',''PICK'')) '   
                  +' AND (LOT.QTY - LOT.QtyAllocated - LOT.QTYPicked - LOT.QtyPreAllocated) > 0 ' 
                  +' AND (LOTxLOCxID.QTY - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QTYPicked) >= 0 ' 
                  +' AND LOC.LocationCategory IN (''MEZZANINEB'',''MEZZANINES'',''HB'',''OTHER'') ' 
                  -- +' AND LOC.PutawayZone IN (''APPERAL'',''FOOTWARE'',''EQUIPMENT'', ''HB'') '
                  +' GROUP BY CASE WHEN LOC.LocationCategory IN (''MEZZANINEB'',''MEZZANINES'') THEN LOC.LocationCategory '
                  +'  WHEN LOC.PutawayZone = ''HB'' THEN ''HB'' ELSE '''' END, LOTxLOCxID.LOC, LOC.Pickzone '    --(Wan01)
                  --+ CASE WHEN ISNUMERIC(@c_CaseCond) = 1 THEN '' ELSE ',' + @c_CaseCond END  --NJOW01 -- (Wan01)
         
    	   DELETE FROM #LOCSeq
         
         IF ISNULL(@c_SQL,'') <> ''
         BEGIN
         	 
            SET @c_SQLParm =  N'@c_Facility   NVARCHAR(5),  @c_StorerKey  NVARCHAR(15), @c_SKU        NVARCHAR(20), ' +    
                               '@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18), ' +
                               '@d_Lottable04 DATETIME,     @d_Lottable05 DATETIME,     @c_Lottable06 NVARCHAR(30), ' +
                               '@c_Lottable07 NVARCHAR(30), @c_Lottable08 NVARCHAR(30), @c_Lottable09 NVARCHAR(30), ' + 
                               '@c_Lottable10 NVARCHAR(30), @c_Lottable11 NVARCHAR(30), @c_Lottable12 NVARCHAR(30), ' + 
                               '@d_Lottable13 DATETIME,     @d_Lottable14 DATETIME,     @d_Lottable15 DATETIME, @c_PickSeq NVARCHAR(10),
                                @c_ListName   NVARCHAR(10) '
            INSERT INTO #LOCSeq (LOC, LocationCategory, AllocSeq, QtyAvailable, QtyAllocated, PickZone) --, ZoneSeq )  --NJOW01      
            EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_Facility, @c_StorerKey, @c_SKU, @c_Lottable01, @c_Lottable02, @c_Lottable03,
                               @d_Lottable04, @d_Lottable05, @c_Lottable06, @c_Lottable07, @c_Lottable08,@c_Lottable09, 
                               @c_Lottable10, @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15, @c_PickSeq, @c_ListName --NJOW2
            IF @b_Debug = 1
            BEGIN
               SELECT * from #LOCSeq     
               --PRINT 'Orderkey:' + @c_Orderkey + ' Orderlinenumber:' + @c_OrderLineNumber                     
            END   
         END
         
         IF NOT EXISTS(SELECT 1 FROM #LOCSeq)
         BEGIN
         	GOTO NEXT_LINE
         END
               
         SET @n_Pack_MezzineB = 0 
         SET @n_Pack_MezzineS = 0
         SET @n_Pack_HB = 0                          
         
         SET @n_MazzanineB_Qty = 0      
         SET @n_MazzanineS_Qty = 0      
         SET @n_HB_Qty         = 0      
   	     SET @c_LOC            = ''     
   	     SET @c_LOC_A          = ''     
   	     SET @c_LOC_B          = ''     
   	     SET @n_LOC_A_Qty      = 0      
   	     SET @n_LOC_B_Qty      = 0      
   	     SET @n_Qty            = 0      
   	     SET @n_AllocSeq       = 0      
 	       
         SELECT TOP 1 
         	   @n_Pack_MezzineB = CASE WHEN ISNUMERIC(s.userdefine01) = 1 THEN CAST(ISNULL(s.userdefine01,'0') AS INT) ELSE 0 END, 
         	   @n_Pack_MezzineS = CASE WHEN ISNUMERIC(s.userdefine02) = 1 THEN CAST(ISNULL(s.userdefine02,'0') AS INT) ELSE 0 END,
         	   @n_Pack_HB       = CASE WHEN ISNUMERIC(s.userdefine03) = 1 THEN CAST(ISNULL(s.userdefine03,'0') AS INT) ELSE 0 END  
         FROM SKUConfig AS s WITH(NOLOCK) 
         WHERE s.StorerKey = @c_StorerKey 
         AND   s.SKU = @c_SKU 
         AND   s.ConfigType = 'NK-PUTAWAY' 
               
         START_ALLOCATION:   	                 
         SET @n_MazzanineB_Qty = 0 
         SET @n_MazzanineS_Qty = 0 
         SET @n_HB_Qty = 0 
         SELECT @n_MazzanineB_Qty = SUM(CASE WHEN l.LocationCategory = 'MEZZANINEB' THEN QtyAvailable - QtyAllocated ELSE 0 END), 
                @n_MazzanineS_Qty = SUM(CASE WHEN l.LocationCategory = 'MEZZANINES' THEN QtyAvailable - QtyAllocated ELSE 0 END),
                @n_HB_Qty = SUM(CASE WHEN l.LocationCategory = 'HB' THEN QtyAvailable - QtyAllocated ELSE 0 END)
                --@n_HB_Qty = SUM(CASE WHEN l.LocationCategory = 'HB' THEN QtyAvailable - QtyAllocated ELSE 0 END)
         FROM #LOCSeq AS l WITH(NOLOCK) 
         
         IF @b_Debug = 1
         BEGIN
         	PRINT '>>> @n_Pack_MezzineB: ' + CAST(@n_Pack_MezzineB AS VARCHAR(10))
         	PRINT '>>> @n_Pack_MezzineS: ' + CAST(@n_Pack_MezzineS AS VARCHAR(10))
         	PRINT '>>> @n_Pack_HB: ' + CAST(@n_Pack_HB AS VARCHAR(10))
         	PRINT '' 
         	PRINT '>>> @n_QtyLeftToFulfill: ' + CAST(@n_QtyLeftToFulfill AS VARCHAR(10))
         	PRINT '>>> Mezzanine Qty: ' + CAST((@n_MazzanineB_Qty + @n_MazzanineS_Qty) AS VARCHAR(10)) 
         	PRINT '>>> @n_HB_Qty: ' + CAST(@n_HB_Qty AS VARCHAR(10)) 
         	PRINT ''
         END
            
         IF (@n_MazzanineB_Qty + @n_MazzanineS_Qty) < @n_QtyLeftToFulfill AND (@n_HB_Qty) > 0 
         BEGIN -- Highbay Allocation 
            IF @b_Debug=1
            BEGIN
               PRINT '>> Highbay Allocation '
               PRINT '----------------------'      	
            END
            
            START_HIGHBAY_ALLOCATION:
            IF @n_QtyLeftToFulfill <= @n_Pack_HB
            BEGIN
               -- Get Location with same qty
         		  SET @c_LOC = ''
         		  
         		  SELECT TOP 1 @c_LOC = l.LOC, @n_Qty = (l.QtyAvailable - l.QtyAllocated)  
         		  FROM #LOCSeq AS l WITH(NOLOCK) 
         		  WHERE l.QtyAvailable - l.QtyAllocated = @n_QtyLeftToFulfill 
         		  AND   l.LocationCategory = 'HB'
         		  ORDER BY l.pickzone, l.Loc --l.ZoneSeq, l.LOC --NJOW01      	
         		  
         		  IF @c_LOC = ''
         		  BEGIN
         		  	 -- AvailableQty equals to Min(AvailableQty>OpenQty)
                  SELECT TOP 1 @c_LOC = l.LOC, @n_Qty = (l.QtyAvailable - l.QtyAllocated)  
         		     FROM #LOCSeq AS l WITH(NOLOCK) 
         		     WHERE l.QtyAvailable - l.QtyAllocated > @n_QtyLeftToFulfill
         		     AND l.LocationCategory = 'HB' 
         		     ORDER BY l.QtyAvailable - l.QtyAllocated, l.pickzone, l.loc  --l.ZoneSeq, l.QtyAvailable - l.QtyAllocated --NJOW01
         		     
         		     IF @b_Debug=1
         		     BEGIN
         		        IF @c_LOC <> ''
         		        BEGIN
         		           PRINT '>>> Found (AvailableQty equals to Min) Loc: ' + @c_LOC
         		        END   
         		     END
         		  END   		
         		
         	    IF @c_LOC = ''
         	    BEGIN
         	       -- AvailableQty By Available Qty Desc
                  SELECT TOP 1 @c_LOC = l.LOC, @n_Qty = (l.QtyAvailable - l.QtyAllocated)  
         	       FROM #LOCSeq AS l WITH(NOLOCK) 
         	       WHERE l.QtyAvailable - l.QtyAllocated > 0
         	       AND l.LocationCategory = 'HB' 
         	       ORDER BY l.QtyAvailable - l.QtyAllocated DESC, l.pickzone, l.loc --l.ZoneSeq, l.QtyAvailable - l.QtyAllocated DESC  --NJOW01
               
         	       IF @b_Debug=1
         	       BEGIN
         	          IF @c_LOC <> ''
         	          BEGIN
         	          	PRINT '>>> Found (Order By Available Qty Desc) Loc: ' + @c_LOC
         	          END   
         	       END   		   
         	    END     		
            END -- @n_QtyLeftToFulfill <= @n_HB_Qty
            ELSE 
            BEGIN
         		  -- AvailableQty By Available Qty Desc
               SELECT TOP 1 @c_LOC = l.LOC, @n_Qty = (l.QtyAvailable - l.QtyAllocated)  
         		  FROM #LOCSeq AS l WITH(NOLOCK) 
         		  WHERE l.QtyAvailable - l.QtyAllocated > 0
         		  AND l.LocationCategory = 'HB' 
         		  ORDER BY l.QtyAvailable - l.QtyAllocated DESC, l.pickzone, l.loc --l.ZoneSeq, l.QtyAvailable - l.QtyAllocated DESC --NJOW01      	
            END
            
         	 IF @c_LOC <> '' AND @n_Qty > 0    		
         	 BEGIN
         	 	  IF @n_Qty > @n_QtyLeftToFulfill
         	 	  	  SET @n_Qty = @n_QtyLeftToFulfill
         	     
         	    SET @n_AllocSeq = @n_AllocSeq + 1
         	    
               UPDATE #LOCSeq 
               SET AllocSeq = @n_AllocSeq, 
                	 QtyAllocated = QtyAllocated + @n_Qty
               WHERE LOC = @c_LOC    	
                  
               SET @n_QtyLeftToFulfill = @n_QtyLeftToFulfill - @n_Qty		
         	 END      
         	 
         	 IF @n_QtyLeftToFulfill > 0 
         	 AND EXISTS(SELECT 1 FROM #LOCSeq
         	            WHERE QtyAvailable > QtyAllocated)
         	 BEGIN
         	 	  IF @b_Debug=1
         	 	  BEGIN
         	 	  	 PRINT ''
         	 	     PRINT 'GOTO START_ALLOCATION'	
         	 	  END
         	 	  
         	 	  GOTO START_ALLOCATION
         	 END   
         END -- Highbay Allocation 
         ELSE 
         IF (@n_MazzanineB_Qty + @n_MazzanineS_Qty) > 0 
         BEGIN -- Mezzanine Allocation
            IF @b_Debug=1
            BEGIN
               PRINT '>> Mezzanine Allocation '
               PRINT '----------------------'      	
            END
                
         	 Start_MezzineB_Allocation:
         	 IF @n_QtyLeftToFulfill <= (@n_Pack_MezzineB * 2)
         	 BEGIN
               IF @b_Debug=1
               BEGIN
                  PRINT '>> QtyLeftToFulfill <= (Pack_MezzineB * 2) '	
               END
                		
         	 	  -- Get Location with same qty
         	 	  SET @c_LOC = ''
         	 	  SET @c_LOC_A = ''
               SET @c_LOC_B = ''
                       		                      		      	 	  
         	 	  SELECT TOP 1 @c_LOC = l.LOC, @n_Qty = (l.QtyAvailable - l.QtyAllocated)  
         	 	  FROM #LOCSeq AS l WITH(NOLOCK)          	 	  
         	 	  WHERE l.QtyAvailable - l.QtyAllocated = @n_QtyLeftToFulfill 
         	 	  AND   l.LocationCategory IN ('MEZZANINEB','MEZZANINES') 
         	 	  ORDER BY l.pickzone, l.Loc --l.ZoneSeq, l.LOC --NJOW01
         	 	  
         	 	  IF @c_LOC = ''
         	 	  BEGIN
         	 	  	  -- AvailableQty equals to Min(AvailableQty>OpenQty)
                   SELECT TOP 1 @c_LOC = l.LOC, @n_Qty = (l.QtyAvailable - l.QtyAllocated)  
         	 	     FROM #LOCSeq AS l WITH(NOLOCK) 
         	 	     WHERE l.QtyAvailable - l.QtyAllocated > @n_QtyLeftToFulfill
         	 	     AND   l.LocationCategory IN ('MEZZANINEB','MEZZANINES') 
         	 	     ORDER BY l.QtyAvailable - l.QtyAllocated, l.pickzone, l.loc --L.ZoneSeq, l.QtyAvailable - l.QtyAllocated --NJOW01		   	
         	 	  END         	 	  
         	 	 
         	 	  IF @c_LOC = ''
         	 	  BEGIN            
                   DECLARE CUR_LOC_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                   SELECT l.LOC, l.QtyAvailable - l.QtyAllocated 
                   FROM #LOCSeq AS l WITH(NOLOCK) 
                   WHERE l.LocationCategory IN ('MEZZANINEB','MEZZANINES') 
                   AND   l.QtyAvailable - l.QtyAllocated  > 0 
                   ORDER BY l.pickzone, l.Loc --l.ZoneSeq, l.LOC --NJOW01
                   
                   OPEN CUR_LOC_LOOP
                   	
                   FETCH NEXT FROM CUR_LOC_LOOP INTO @c_LOC_A, @n_LOC_A_Qty
                   WHILE @@FETCH_STATUS = 0
                   BEGIN
         	 	  	     IF @b_Debug=1
         	 	  	     BEGIN
         	 	  		     PRINT '>>> @c_LOC_A: ' + @c_LOC_A
         	 	  		     PRINT '>>> @n_LOC_A_Qty: ' + CAST(@n_LOC_A_Qty AS VARCHAR(10))
         	 	  	     END
         	 	  	               	
                      SET @c_LOC_B = ''
                      SET @n_LOC_B_Qty = 0
                      
                      SELECT @c_LOC_B = LOC, @n_LOC_B_Qty = (l.QtyAvailable - l.QtyAllocated )
                      FROM #LOCSeq AS l WITH(NOLOCK)
                      WHERE l.LOC > @c_LOC_A 
                      AND (l.QtyAvailable - l.QtyAllocated) = @n_QtyLeftToFulfill - @n_LOC_A_Qty
                      AND l.LocationCategory IN ('MEZZANINEB','MEZZANINES')
                      ORDER BY l.pickzone, l.loc --l.ZoneSeq --NJOW01
                      	 
         	 	  	     IF @b_Debug=1
         	 	  	     BEGIN
         	 	  		     PRINT '>>> @c_LOC_B: ' + @c_LOC_B
         	 	  		     PRINT '>>> @n_LOC_B_Qty: ' + CAST(@n_LOC_B_Qty AS VARCHAR(10))
         	 	  	     END            	
         	 	  	   
                      IF @c_LOC_B <> ''
                      BEGIN
                      	SET @n_AllocSeq = @n_AllocSeq + 1
                      	
                      	UPDATE #LOCSeq 
                      	   SET AllocSeq = @n_AllocSeq, 
                      	       QtyAllocated = QtyAllocated + @n_LOC_A_Qty
                      	WHERE LOC = @c_LOC_A 
                      
                          SET @n_QtyLeftToFulfill = @n_QtyLeftToFulfill - @n_LOC_A_Qty
                          
                          SET @n_AllocSeq = @n_AllocSeq + 1
                      	UPDATE #LOCSeq 
                      	   SET AllocSeq = @n_AllocSeq, 
                      	       QtyAllocated = QtyAllocated + @n_LOC_B_Qty
                      	WHERE LOC = @c_LOC_B 
                      	SET @n_QtyLeftToFulfill = @n_QtyLeftToFulfill - @n_LOC_B_Qty
                      	
                      	BREAK 
                      END
                      	
                      FETCH NEXT FROM CUR_LOC_LOOP INTO @c_LOC_A, @n_LOC_A_Qty
                   END -- While 
                   CLOSE CUR_LOC_LOOP
                   DEALLOCATE CUR_LOC_LOOP
         	 	  END -- Find two locations(a and b) where sum(qty) = @n_QtyLeftToFulfill
         	 	  
         	 	  IF @c_LOC = '' AND @c_LOC_B = ''
         	 	  BEGIN -- Locations sort by AvailableQty desc
                  SELECT TOP 1 @c_LOC = l.LOC, @n_Qty = (l.QtyAvailable - l.QtyAllocated)  
         	 	     FROM #LOCSeq AS l WITH(NOLOCK) 
         	 	     WHERE l.QtyAvailable - l.QtyAllocated > 0
         	 	     AND l.LocationCategory IN ('MEZZANINEB','MEZZANINES') 
         	 	     ORDER BY l.QtyAvailable - l.QtyAllocated DESC, l.pickzone, l.loc --l.ZoneSeq, l.QtyAvailable - l.QtyAllocated DESC --NJOW01  
         	 	     
         	 	     IF @c_LOC = ''
         	 	        GOTO End_MezzineB_Allocation   			 		   	
         	 	  END
         	 	  
         	 	  IF @c_LOC <> '' AND @n_Qty > 0 AND @c_LOC_B = ''  		
         	 	  BEGIN
         	 	     IF @n_Qty > @n_QtyLeftToFulfill
         	 	        SET @n_Qty = @n_QtyLeftToFulfill
         	 	           
         	 	     SET @n_AllocSeq = @n_AllocSeq + 1
                  UPDATE #LOCSeq 
                  SET AllocSeq = @n_AllocSeq, 
                      QtyAllocated = QtyAllocated + @n_Qty
                  WHERE LOC = @c_LOC    	
                    
                  SET @n_QtyLeftToFulfill = @n_QtyLeftToFulfill - @n_Qty
                  IF @n_QtyLeftToFulfill = 0 
                     GOTO End_MezzineB_Allocation 
                  ELSE 
                   	GOTO Start_MezzineB_Allocation	
         	 	  END  
         	 END -- IF @n_QtyLeftToFulfill <= (@n_Pack_MezzineB * 2)
         	 ELSE 
         	 BEGIN
               IF @b_Debug=1
               BEGIN
                  PRINT '>> QtyLeftToFulfill > (Pack_MezzineB * 2) '	
               END
                   		
         	 	 -- Qty to allocate is more than two times of PK(MezzanineB)
         	 	 WHILE @n_QtyLeftToFulfill > 0 
         	 	 BEGIN
         	 	 	  SET @c_LOC = ''
         	 	 	  SET @n_Qty = 0 
         	 	 	
                 SELECT TOP 1 
                        @c_LOC = l.LOC,  
                        @n_Qty = (l.QtyAvailable - l.QtyAllocated)
         	 	    FROM #LOCSeq AS l WITH(NOLOCK) 
         	 	    WHERE l.QtyAvailable - l.QtyAllocated > 0
         	 	    AND l.LocationCategory IN ('MEZZANINEB','MEZZANINES') 
         	 	    ORDER BY (l.QtyAvailable - l.QtyAllocated) DESC, l.pickzone, l.LOC --l.ZoneSeq, (l.QtyAvailable - l.QtyAllocated) DESC, l.LOC --NJOW01  
         	 	    IF @@ROWCOUNT = 0 
         	 	       BREAK 
         	 	       
         	 	    IF @c_LOC <> '' AND @n_Qty > 0 			
         	 	    BEGIN
         	 	 	     IF @n_Qty > @n_QtyLeftToFulfill
         	 	 	        SET @n_Qty = @n_QtyLeftToFulfill
         	 	 	     
         	 	 	     SET @n_AllocSeq = @n_AllocSeq + 1
                    
                    UPDATE #LOCSeq 
                    SET AllocSeq = @n_AllocSeq, 
                        QtyAllocated = QtyAllocated + @n_Qty
                    WHERE LOC = @c_LOC    	
                      
                    SET @n_QtyLeftToFulfill = @n_QtyLeftToFulfill - @n_Qty		   		   	

                    IF @b_Debug=1
                    BEGIN
                       PRINT '>> Loc: ' + @c_Loc	
                       PRINT '>> Qty: ' + CAST(@n_qty AS NVARCHAR)
                    END                    
         	 	    END
         	 	    
         	 	    IF @n_QtyLeftToFulfill > 0 AND (@n_QtyLeftToFulfill <= (@n_Pack_MezzineB * 2))
         	 	    BEGIN
         	 	    	 IF EXISTS(SELECT 1 FROM #LOCSeq AS l WITH(NOLOCK)
         	 	    	           WHERE l.QtyAvailable > l.QtyAllocated
         	 	    	           AND l.LocationCategory IN ('MEZZANINEB','MEZZANINES') )
         	 	    	 BEGIN
         	 	    	 	 GOTO Start_MezzineB_Allocation 
         	 	    	 END   		   	 
         	 	    END   		      
         	 	 END
         	 END   	
         END -- Mezzanine Allocation
         End_MezzineB_Allocation:
               
         IF @b_Debug = 1
         BEGIN
         	 PRINT ''    	
            SELECT * from #LOCSeq
         END         
                                                                       
         DECLARE CUR_LOC_Sequence CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT LOC, QtyAllocated
            FROM #LOCSeq 
            WHERE AllocSeq > 0 
            AND   QtyAllocated > 0 
            ORDER BY AllocSeq 
         
         OPEN CUR_LOC_Sequence
         
         FETCH FROM CUR_LOC_Sequence INTO @c_LOC, @n_QtyAllocated
         
         WHILE @@FETCH_STATUS = 0 AND @n_OpenQty > 0 AND @n_continue IN(1,2)
         BEGIN  	
           SET @c_SQL = ' DECLARE CUR_LOTxLOCxID CURSOR FAST_FORWARD READ_ONLY FOR
                              SELECT LOTxLOCxID.Lot, 
                                     LOTxLOCxID.Loc, 
                                     LOTxLOCxID.Id, 
                                     LOTxLOCxID.Qty - (LOTxLOCxID.QtyAllocated + LOTxLOCxID.QtyPicked) 
                              FROM LOTxLOCxID WITH (NOLOCK) 
                              JOIN LOTATTRIBUTE WITH (NOLOCK) ON LOTxLOCxID.Lot = LOTATTRIBUTE.Lot
                              JOIN LOC WITH (NOLOCK) ON LOTxLOCxID.Loc = LOC.Loc '
                           +  CASE WHEN ISNULL(@c_PickSeq,'') <> '' THEN ' JOIN CODELKUP CL (NOLOCK) ON CL.Listname = @c_ListName AND CL.Storerkey = @c_Storerkey AND CL.Code2 = LOC.PickZone AND CL.Short = @c_PickSeq ' ELSE ' ' END + --NJOW01
                            ' WHERE LOTxLOCxID.Loc = @c_LOC 
                              AND   LOTxLOCxID.StorerKey = @c_StorerKey 
                              AND   LOTxLOCxID.Sku = @c_SKU 
                              AND   LOTxLOCxID.Qty > (LOTxLOCxID.QtyAllocated + LOTxLOCxID.QtyPicked) ' 
                              +  @c_LimitString + ' '                                
            
            SET @c_SQLParm =  N'@c_Loc 			 NVARCHAR(10), @c_StorerKey  NVARCHAR(15), @c_SKU        NVARCHAR(20), ' +    
                               '@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18), ' +
                               '@d_Lottable04 DATETIME,     @d_Lottable05 DATETIME,     @c_Lottable06 NVARCHAR(30), ' +
                               '@c_Lottable07 NVARCHAR(30), @c_Lottable08 NVARCHAR(30), @c_Lottable09 NVARCHAR(30), ' + 
                               '@c_Lottable10 NVARCHAR(30), @c_Lottable11 NVARCHAR(30), @c_Lottable12 NVARCHAR(30), ' + 
                               '@d_Lottable13 DATETIME,     @d_Lottable14 DATETIME,     @d_Lottable15 DATETIME, @c_PickSeq NVARCHAR(10),
                                @c_ListName   NVARCHAR(10) '
                               
            EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_Loc, @c_StorerKey, @c_SKU, @c_Lottable01, @c_Lottable02, @c_Lottable03,
                               @d_Lottable04, @d_Lottable05, @c_Lottable06, @c_Lottable07, @c_Lottable08,@c_Lottable09, 
                               @c_Lottable10, @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15, @c_PickSeq, @c_ListName --NJOW02
         	
         	OPEN CUR_LOTxLOCxID
         	
         	FETCH FROM CUR_LOTxLOCxID INTO @c_Lot, @c_Loc, @c_Id, @n_Qty 
         	
         	WHILE @@FETCH_STATUS = 0 AND @n_QtyAllocated > 0 AND @n_OpenQty > 0 AND @n_continue IN(1,2)
         	BEGIN
         		 IF @n_Qty > @n_QtyAllocated
         		    SET @n_Qty = @n_QtyAllocated 
         
              IF @n_Qty > @n_OpenQty 
              	  SET @n_Qty = @n_OpenQty
              
   		   	   SET @b_Success = 0 
   		   	   SET @c_PickDetailKey = ''
   		        EXEC nspg_GetKey
   		   	     @KeyName = 'PickdetailKey',
   		   	     @fieldlength = 10,
   		   	     @keystring = @c_PickDetailKey OUTPUT,
   		   	     @b_Success = @b_Success OUTPUT,
   		   	     @n_err = @n_Err OUTPUT,
   		   	     @c_errmsg = @c_ErrMsg OUTPUT,
   		   	     @b_resultset = 1,
   		   	     @n_batch = 1
         
              IF @b_Success = 1
              BEGIN              	           	    
              	 INSERT INTO PICKDETAIL
              	 (
              	 	PickDetailKey,          CaseID,            	 PickHeaderKey,
              	 	OrderKey,               OrderLineNumber,     Lot,
              	 	Storerkey,              Sku,            	 	 AltSku,
              	 	UOM,           		      UOMQty,            	 Qty,
              	 	QtyMoved,               [Status],            DropID,
              	 	Loc,            		    ID,            	     PackKey,
              	 	UpdateSource,           CartonGroup,         CartonType,
              	 	ToLoc,            	    DoReplenish,         ReplenishZone,
              	 	DoCartonize,            PickMethod,          WaveKey,
              	 	ShipFlag,               PickSlipNo,          TaskDetailKey,
              	 	TaskManagerReasonKey,   Notes,            	MoveRefKey    )
              	 VALUES
              	 (@c_PickDetailKey,    '',            		'',
              	 	@c_OrderKey,         @c_OrderLineNumber,  @c_LOT,
              	 	@c_StorerKey,        @c_SKU,           	'',
              	 	@c_UOM,             	@n_Qty,           @n_Qty,
              	 	0,            		   '0',            		'',
              	 	@c_LOC,              	@c_ID,            	@c_PackKey,
              	 	'0',            		   '',            		'',
              	 	'',            		   'N',            		'',
              	 	'N',            		  '',            		'',
              	 	'N',            		  '',            		'',
              	 	'',            		    '',            		'' )      
              	 	
                 SET @n_err = @@ERROR     
         
                 IF @n_err <> 0      
                 BEGIN    
                    SET @n_continue = 3      
                    SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)    
                    SET @n_err = 81010  -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
                    SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Pickdetail Failed. (ispPRALC03)'   
                                 + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '      
                 END                            	 	        	 	
              END -- GetKey @b_Success = 1				                	                               
            	 
            	 SET @n_OpenQty = @n_OpenQty - @n_Qty              	                 	   	
              SET @n_QtyAllocated = @n_QtyAllocated - @n_Qty    	   	
                        	   
         		 FETCH FROM CUR_LOTxLOCxID INTO @c_Lot, @c_Loc, @c_Id, @n_Qty
         	END   	
         	CLOSE CUR_LOTxLOCxID
         	DEALLOCATE CUR_LOTxLOCxID
         
         	FETCH FROM CUR_LOC_Sequence INTO @c_LOC, @n_QtyAllocated
         END
         CLOSE CUR_LOC_Sequence
         DEALLOCATE CUR_LOC_Sequence      
   
         NEXT_LINE: 
        
         FETCH FROM CUR_PICKSEQ INTO @c_PickSeq, @c_ListName --NJOW02                                            
      END
      CLOSE CUR_PICKSEQ
      DEALLOCATE CUR_PICKSEQ
                         
      FETCH FROM CUR_ORDER_LINES INTO @c_StorerKey, @c_OrderKey, @c_OrderLineNumber, @c_SKU, @n_OpenQty, @c_Packkey, @n_CaseCnt,
                                      @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05, @c_Lottable06, @c_Lottable07, @c_Lottable08, 
                                      @c_Lottable09, @c_Lottable10, @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15, @c_Facility,
                                      @c_Consigneekey, @c_B_State, @c_Country --NJOW02                                                                                                                                                  
   END -- CUR_ORDER_LINES   
   CLOSE CUR_ORDER_LINES
   DEALLOCATE CUR_ORDER_LINES
 	
QUIT:

   IF @n_Continue=3  -- Error Occured - Process And Return  
   BEGIN  
      SELECT @b_Success = 0  
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt  
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
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispPRALC03'  
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
      RETURN  
   END  
   ELSE  
   BEGIN  
      SELECT @b_Success = 1  
      WHILE @@TRANCOUNT > @n_StartTCnt  
      BEGIN  
         COMMIT TRAN  
      END  
      RETURN  
   END   	
END    

GO