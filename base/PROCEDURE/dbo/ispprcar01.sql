SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Stored Procedure: ispPRCAR01                                         */    
/* Creation Date: 02-Feb-2016                                           */    
/* Copyright: LFL                                                       */    
/* Written by:                                                          */    
/*                                                                      */    
/* Purpose: 358754 - CN Carters SZ - Pre-Allocation process to allocate */
/*          full pallet by ship-to(M_Address4) and omnia order#         */
/*          (Userdefine03) or single order(AE) from pallet location     */ 
/*          For IFC, Traditional, Asia ECOM and skip hop only.          */
/*          Set to storerconfig PreProcessingStrategyKey                */ 
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
/* Date         Author    Ver.  Purposes                                */
/* 23-Feb-2018  NJOW01    1.0   WMS-4038 change M_ISOCntrycode to       */
/*                              M_address4. Include AE single order.    */
/*                              Allow multi lot / ucc in full pallet    */
/* 22-Jan-2020  NJOW02    1.1   WMS-11883 Include Skip Hop              */
/* 02-Apr-2020  NJOW02    1.2   WMS-11883 Fix skip hop preallocation    */
/************************************************************************/    
CREATE PROC [dbo].[ispPRCAR01]        
    @c_WaveKey                      NVARCHAR(10)
  , @c_UOM                          NVARCHAR(10)
  , @c_LocationTypeOverride         NVARCHAR(10)
  , @c_LocationTypeOverRideStripe   NVARCHAR(10)
  , @b_Success                      INT           OUTPUT  
  , @n_Err                          INT           OUTPUT  
  , @c_ErrMsg                       NVARCHAR(250) OUTPUT  
  , @b_Debug                        INT = 0
AS    
BEGIN    
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET ANSI_NULLS OFF    

   DECLARE  
      @n_Continue    INT,  
      @n_StartTCnt   INT,
      @c_SQL         NVARCHAR(MAX),    
      @c_SQLParm     NVARCHAR(MAX),
      @n_LowerBound  INT

   DECLARE 
      @n_OrderQty          INT,
      @n_InsertQty         INT,
      @n_IDQty             INT,
      @n_OrderLineQty      INT, 
      @c_Loc               NVARCHAR(10),
      @c_Lot               NVARCHAR(10),
      @c_ID                NVARCHAR(18),
      @c_OrderKey          NVARCHAR(10),
      @c_OrderLineNumber   NVARCHAR(5),
      @c_Facility          NVARCHAR(5),     
      @c_StorerKey         NVARCHAR(15),     
      @c_LocationType      NVARCHAR(10),    
      @c_LocationCategory  NVARCHAR(10),
      @c_SKU               NVARCHAR(20),    
      @c_Lottable01        NVARCHAR(18),    
      @c_Lottable02        NVARCHAR(18),    
      @c_Lottable03        NVARCHAR(18),
      @c_Lottable06        NVARCHAR(30),
      @c_Lottable07        NVARCHAR(30),
      @c_Lottable08        NVARCHAR(30),
      @c_Lottable09        NVARCHAR(30),
      @c_Lottable10        NVARCHAR(30),
      @c_Lottable11        NVARCHAR(30),
      @c_Lottable12        NVARCHAR(30),
      @c_PickDetailKey     NVARCHAR(10),
      @n_PickQty           INT,
      @c_PackKey           NVARCHAR(10),  
      @c_PickMethod        NVARCHAR(1),
      --@c_Wavekey           NVARCHAR(10),
      @c_WaveType          NVARCHAR(10),
      @c_ShipTo            NVARCHAR(45), --NJOW01
      @c_OmniaOrderNo      NVARCHAR(20),
      @c_LocationHandling  NVARCHAR(10),
      @n_QtyAvailable      INT,  --NJOW02
      @d_Lottable05        DATETIME, --NJOW02
      @n_LotQty            INT, --NJOW02
      @c_UCCNO             NVARCHAR(20), --NJOW02
      @n_UCCQty            INT, --NJOW02
      @c_LocationHDL       NVARCHAR(10), --NJOW02
      @n_UpdateQty         INT, --NJOW02
      @n_Qty               INT, --NJOW02
      @n_SeqNo             INT --NJOW02
      

   -- FROM BULK Area 
   SET @c_LocationType = 'OTHER'      
   SET @c_LocationCategory = 'BULK'
   SET @c_LocationHandling = '1'  --1=Pallet 2=Case
   SET @c_PickMethod = 'P'
   SET @c_UOM = '2'

   SELECT @n_StartTCnt = @@TRANCOUNT , @n_Continue=1, @b_Success=1, @n_Err=0, @c_ErrMsg=''
   
   --SELECT TOP 1 @c_Wavekey = Userdefine09
   --FROM ORDERS(NOLOCK)
   --WHERE Loadkey = @c_Loadkey
        
   SELECT @c_WaveType = DispatchPiecePickMethod
   FROM WAVE (NOLOCK)
   WHERE Wavekey = @c_Wavekey

   IF ISNULL(@c_WaveType,'') NOT IN('I','T','H','E','S')
   BEGIN   
      SET @n_Err = 13000
      SET @n_Continue = 3
      SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) + 
                      ': Invalid Wave Piece Pick Task Dispatch Method. Must Be I,H,T,E or S (ispPRCAR01)'
      GOTO Quit
   END                     
   
   IF ISNULL(@c_WaveType,'') = 'H' 
     GOTO Quit

   /*****************************/
   /***   CREATE TEMP TABLE   ***/
   /*****************************/
   
   --NJOW02       
   IF OBJECT_ID('tempdb..##CARLOT','u') IS NOT NULL
   BEGIN
   	  DELETE FROM ##CARLOT
   	  WHERE SP_ID = @@SPID
   	  OR DATEDIFF(Day, AddDate, Getdate()) > 0
   END
   ELSE IF ISNULL(@c_WaveType,'') = 'S' 
   BEGIN
   	  CREATE TABLE ##CARLOT (
   	  SeqNo        INT IDENTITY(1, 1),
   	  Lot          NVARCHAR(10), 
   	  Qty          INT,
   	  QtyAllocated INT,
   	  SP_ID        INT,
   	  AddDate      DATETIME DEFAULT(GETDATE()))
   END   	    

   --NJOW02
   IF ISNULL(@c_WaveType,'') = 'S' 
   BEGIN 
      CREATE TABLE #ORDERGROUP (  
      SeqNo             INT IDENTITY(1, 1),  
      StorerKey         NVARCHAR(15), 
      SKU               NVARCHAR(20),
      Facility          NVARCHAR(5),  
      ShipTo            NVARCHAR(45), --Orders.M_address4  --NJOW01
      OmniaOrderNo      NVARCHAR(20), --Orders.Userdefine03
      Lottable01        NVARCHAR(18), 
      Lottable02        NVARCHAR(18), 
      Lottable03        NVARCHAR(18),
      Lottable06        NVARCHAR(30),
      Lottable07        NVARCHAR(30),
      Lottable08        NVARCHAR(30),
      Lottable09        NVARCHAR(30),
      Lottable10        NVARCHAR(30),
      Lottable11        NVARCHAR(30),
      Lottable12        NVARCHAR(30),
      OrderQty          INT
      )

   	  CREATE TABLE #LotAttributeAllocated (
   	  SeqNo      INT IDENTITY(1, 1),
      StorerKey  NVARCHAR(15), 
      SKU        NVARCHAR(20),
      Facility   NVARCHAR(5),  
      Lottable01 NVARCHAR(18), 
      Lottable02 NVARCHAR(18), 
      Lottable03 NVARCHAR(18),
      Lottable06 NVARCHAR(30),
      Lottable07 NVARCHAR(30),
      Lottable08 NVARCHAR(30),
      Lottable09 NVARCHAR(30),
      Lottable10 NVARCHAR(30),
      Lottable11 NVARCHAR(30),
      Lottable12 NVARCHAR(30),
   	  Lottable05 DATETIME,
   	  Qty        INT
   	  )

      CREATE TABLE #IDxLOC_USED (  
         SeqNo        INT IDENTITY(1, 1),
         ID           NVARCHAR(18), 
         LOC          NVARCHAR(10),
         LOCKTYPE     NCHAR(1)
      )   	  

      CREATE TABLE #UCC_USED (  
         SeqNo        INT IDENTITY(1, 1),
         UCCNo        NVARCHAR(20) 
      )   	  
   END

   IF OBJECT_ID('tempdb..#ORDERLINES','u') IS NOT NULL
      DROP TABLE #ORDERLINES;

   -- Store all OrderDetail in Wave
   CREATE TABLE #ORDERLINES (  
      SeqNo             INT IDENTITY(1, 1),  
      ShipTo            NVARCHAR(45), --Orders.M_address4  --NJOW01
      OmniaOrderNo      NVARCHAR(20), --Orders.Userdefine03
      OrderQty          INT, 
      SKU               NVARCHAR(20),
      PackKey           NVARCHAR(10), 
      StorerKey         NVARCHAR(15), 
      Facility          NVARCHAR(5),  
      Lottable01        NVARCHAR(18), 
      Lottable02        NVARCHAR(18), 
      Lottable03        NVARCHAR(18),
      Lottable06        NVARCHAR(30),
      Lottable07        NVARCHAR(30),
      Lottable08        NVARCHAR(30),
      Lottable09        NVARCHAR(30),
      Lottable10        NVARCHAR(30),
      Lottable11        NVARCHAR(30),
      Lottable12        NVARCHAR(30)
   )

   IF OBJECT_ID('tempdb..#LOTxLOCxID','u') IS NOT NULL
      DROP TABLE #LOTxLOCxID;

   -- Store Stock in Inventory (LOTxLOCxID info)
   CREATE TABLE #LOTxLOCxID (  
      Loc               NVARCHAR(10), 
      LogicalLocation   NVARCHAR(18), 
      [Lot]             NVARCHAR(10), 
      [ID]              NVARCHAR(18),
      Qty               INT,
      QtyAvailable      INT,
      QtyReplen         INT,  --NJOW01
      UCCNo             NVARCHAR(20) --NJOW02
   )

   IF OBJECT_ID('tempdb..#IDxLOC','u') IS NOT NULL
      DROP TABLE #IDxLOC;

   CREATE TABLE #IDxLOC (  
      SeqNo        INT IDENTITY(1, 1),
      ID           NVARCHAR(18), 
      LOC          NVARCHAR(10),
      QtyAvailable INT
   )
   
   --NJOW02 S
   IF ISNULL(@c_WaveType,'') = 'S'
   BEGIN
   	  ----PreAllocate qty by order lottable split by lottable05
   	  IF @n_continue IN (1,2)
   	  BEGIN
         DECLARE CURSOR_ORDERDET CURSOR LOCAL FAST_FORWARD READ_ONLY FOR        
            SELECT ISNULL(RTRIM(OD.Sku),''),
                   ISNULL(RTRIM(OD.Storerkey),''),
                   ISNULL(RTRIM(O.Facility),''),
                   ISNULL(RTRIM(OD.Lottable01),''),
                   ISNULL(RTRIM(OD.Lottable02),''),
                   ISNULL(RTRIM(OD.Lottable03),''),
                   ISNULL(RTRIM(OD.Lottable06),''),
                   ISNULL(RTRIM(OD.Lottable07),''),
                   ISNULL(RTRIM(OD.Lottable08),''),
                   ISNULL(RTRIM(OD.Lottable09),''),
                   ISNULL(RTRIM(OD.Lottable10),''),
                   ISNULL(RTRIM(OD.Lottable11),''),
                   ISNULL(RTRIM(OD.Lottable12),''),
                   SUM(OD.OpenQty - (OD.QtyAllocated + OD.QtyPreAllocated + OD.QtyPicked))                                                
            FROM ORDERDETAIL OD WITH (NOLOCK)  
            JOIN SKU WITH (NOLOCK) ON SKU.StorerKey = OD.StorerKey AND SKU.Sku = OD.Sku  
            JOIN ORDERS O WITH (NOLOCK) ON O.OrderKey = OD.OrderKey  
            JOIN WAVEDETAIL WD WITH (NOLOCK) ON OD.OrderKey = WD.OrderKey
            WHERE WD.WaveKey = @c_WaveKey
            AND O.Type NOT IN ( 'M', 'I' )   
            AND O.SOStatus <> 'CANC'   
            AND O.Status < '9'   
            AND (OD.OpenQty - ( OD.QtyAllocated + OD.QtyPreAllocated + OD.QtyPicked )) > 0       
            GROUP BY ISNULL(RTRIM(OD.Sku),''),            
                     ISNULL(RTRIM(OD.Storerkey),''),      
                     ISNULL(RTRIM(O.Facility),''),        
                     ISNULL(RTRIM(OD.Lottable01),''),     
                     ISNULL(RTRIM(OD.Lottable02),''),     
                     ISNULL(RTRIM(OD.Lottable03),''),     
                     ISNULL(RTRIM(OD.Lottable06),''),     
                     ISNULL(RTRIM(OD.Lottable07),''),     
                     ISNULL(RTRIM(OD.Lottable08),''),     
                     ISNULL(RTRIM(OD.Lottable09),''),     
                     ISNULL(RTRIM(OD.Lottable10),''),     
                     ISNULL(RTRIM(OD.Lottable11),''),     
                     ISNULL(RTRIM(OD.Lottable12),'')
         
         OPEN CURSOR_ORDERDET           
         FETCH NEXT FROM CURSOR_ORDERDET INTO @c_SKU, @c_StorerKey, @c_Facility, @c_Lottable01, @c_Lottable02, @c_Lottable03, @c_Lottable06,
                                              @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10, @c_Lottable11, @c_Lottable12, @n_OrderQty
             
         WHILE (@@FETCH_STATUS <> -1)          
         BEGIN      	
            IF (SELECT CURSOR_STATUS('GLOBAL','CURSOR_LOT1')) >=0 
            BEGIN
               CLOSE CURSOR_LOT1           
               DEALLOCATE CURSOR_LOT1    
            END  
         	
            SET @c_SQL = N'
                DECLARE CURSOR_LOT1 CURSOR FAST_FORWARD READ_ONLY FOR
                SELECT LA.Lottable05, SUM(LOTXLOCXID.Qty - LOTXLOCXID.QtyAllocated - LOTXLOCXID.QtyPicked - LOTXLOCXID.QtyReplen) AS QtyAvailable
                FROM LOTxLOCxID WITH (NOLOCK)      
                   JOIN LOC WITH (NOLOCK) ON (LOTxLOCxID.Loc = LOC.LOC)      
                   JOIN ID WITH (NOLOCK) ON (LOTxLOCxID.Id = ID.ID AND ID.STATUS = ''OK'')       
                   JOIN LOT WITH (NOLOCK) ON (LOTXLOCXID.LOT = LOT.LOT AND LOT.STATUS = ''OK'')         
                   JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON LOT.LOT = LA.LOT            
                WHERE LOC.LocationFlag = ''NONE''       
                   AND LOC.Status = ''OK''       
                   AND LOC.Facility = @c_Facility   
                   AND LOTxLOCxID.STORERKEY = @c_StorerKey
                   AND LOTxLOCxID.SKU = @c_SKU ' + CHAR(13) +
                   CASE WHEN ISNULL(RTRIM(@c_Lottable01),'') = '' THEN '' ELSE ' AND LA.Lottable01 = @c_Lottable01 ' + CHAR(13) END +      
                   CASE WHEN ISNULL(RTRIM(@c_Lottable02),'') = '' THEN '' ELSE ' AND LA.Lottable02 = @c_Lottable02 ' + CHAR(13) END +      
                   CASE WHEN ISNULL(RTRIM(@c_Lottable03),'') = '' THEN '' ELSE ' AND LA.Lottable03 = @c_Lottable03 ' + CHAR(13) END +  
                   CASE WHEN ISNULL(RTRIM(@c_Lottable06),'') = '' THEN '' ELSE ' AND LA.Lottable06 = @c_Lottable06 ' + CHAR(13) END +  
                   CASE WHEN ISNULL(RTRIM(@c_Lottable07),'') = '' THEN '' ELSE ' AND LA.Lottable07 = @c_Lottable07 ' + CHAR(13) END +  
                   CASE WHEN ISNULL(RTRIM(@c_Lottable08),'') = '' THEN '' ELSE ' AND LA.Lottable08 = @c_Lottable08 ' + CHAR(13) END +  
                   CASE WHEN ISNULL(RTRIM(@c_Lottable09),'') = '' THEN '' ELSE ' AND LA.Lottable09 = @c_Lottable09 ' + CHAR(13) END +  
                   CASE WHEN ISNULL(RTRIM(@c_Lottable10),'') = '' THEN '' ELSE ' AND LA.Lottable10 = @c_Lottable10 ' + CHAR(13) END +  
                   CASE WHEN ISNULL(RTRIM(@c_Lottable11),'') = '' THEN '' ELSE ' AND LA.Lottable11 = @c_Lottable11 ' + CHAR(13) END +  
                   CASE WHEN ISNULL(RTRIM(@c_Lottable12),'') = '' THEN '' ELSE ' AND LA.Lottable12 = @c_Lottable12 ' + CHAR(13) END +  
                   'AND (LOTxLOCxID.QTY - LOTXLOCXID.QtyAllocated - LOTXLOCXID.QtyPicked - LOTXLOCXID.QtyReplen)  > 0 
                   GROUP BY LA.Lottable05
                   ORDER BY LA.Lottable05'
                   
            SET @c_SQLParm =  N'@c_Facility NVARCHAR(5), @c_StorerKey NVARCHAR(15), @c_SKU NVARCHAR(20), ' +      
                              '@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18), ' + 
                              '@c_Lottable06 NVARCHAR(30), @c_Lottable07 NVARCHAR(30), @c_Lottable08 NVARCHAR(30), ' + 
                              '@c_Lottable09 NVARCHAR(30), @c_Lottable10 NVARCHAR(30), @c_Lottable11 NVARCHAR(30), ' + 
                              '@c_Lottable12 NVARCHAR(30)' 
                     
            EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_Facility, @c_StorerKey, @c_SKU, @c_Lottable01, @c_Lottable02, @c_Lottable03, 
                               @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10, @c_Lottable11, @c_Lottable12
                               
            OPEN CURSOR_LOT1           
             
            FETCH NEXT FROM CURSOR_LOT1 INTO @d_Lottable05, @n_QtyAvailable

            WHILE (@@FETCH_STATUS <> -1) AND @n_OrderQty > 0          
            BEGIN
            	  IF @n_OrderQty >= @n_QtyAvailable
            	     SET @n_InsertQty = @n_QtyAvailable
            	  ELSE
            	     SET @n_InsertQty = @n_OrderQty
            	  
            	  INSERT INTO #LotattributeAllocated (StorerKey, SKU, Facility, Lottable01, Lottable02, Lottable03, Lottable06,
                                              Lottable07, Lottable08, Lottable09, Lottable10, Lottable11, Lottable12, Lottable05, Qty)
            	  VALUES (@c_StorerKey, @c_SKU, @c_Facility, @c_Lottable01, @c_Lottable02, @c_Lottable03, @c_Lottable06,
                                              @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10, @c_Lottable11, @c_Lottable12, @d_Lottable05, @n_QtyAvailable)
            	  
            	  SET @n_OrderQty = @n_OrderQty - @n_InsertQty
            	
               FETCH NEXT FROM CURSOR_LOT1 INTO @d_Lottable05, @n_QtyAvailable
            END        
            CLOSE CURSOR_LOT1 
            DEALLOCATE CURSOR_LOT1                    
                                             	      	
            FETCH NEXT FROM CURSOR_ORDERDET INTO @c_SKU, @c_StorerKey, @c_Facility, @c_Lottable01, @c_Lottable02, @c_Lottable03, @c_Lottable06,
                                                 @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10, @c_Lottable11, @c_Lottable12, @n_OrderQty
         END        
         CLOSE CURSOR_ORDERDET
         DEALLOCATE CURSOR_ORDERDET    
      END
      
      ----Create Order grouping by Shipto, OmniaOrderNo, lottables, qty
      IF @n_continue IN(1,2)
      BEGIN
   	     INSERT INTO #ORDERGROUP (Storerkey, Sku, Facility, Shipto, OmniaOrderNo, Lottable01, Lottable02, Lottable03, Lottable06, Lottable07, Lottable08, Lottable09, Lottable10, Lottable11, Lottable12, OrderQty)
            SELECT ISNULL(RTRIM(OD.Storerkey),''), 
                   ISNULL(RTRIM(OD.Sku),''),                
                   ISNULL(RTRIM(O.Facility),''),                
                   ISNULL(RTRIM(O.M_Address4),''),
                   ISNULL(RTRIM(O.Userdefine03),''),                
                   ISNULL(RTRIM(OD.Lottable01),''),
                   ISNULL(RTRIM(OD.Lottable02),''),
                   ISNULL(RTRIM(OD.Lottable03),''),
                   ISNULL(RTRIM(OD.Lottable06),''),
                   ISNULL(RTRIM(OD.Lottable07),''),
                   ISNULL(RTRIM(OD.Lottable08),''),
                   ISNULL(RTRIM(OD.Lottable09),''),
                   ISNULL(RTRIM(OD.Lottable10),''),
                   ISNULL(RTRIM(OD.Lottable11),''),
                   ISNULL(RTRIM(OD.Lottable12),''),
                   SUM(OD.OpenQty - (OD.QtyAllocated + OD.QtyPreAllocated + OD.QtyPicked))                                                
            FROM ORDERDETAIL OD WITH (NOLOCK)  
            JOIN SKU WITH (NOLOCK) ON SKU.StorerKey = OD.StorerKey AND SKU.Sku = OD.Sku  
            JOIN ORDERS O WITH (NOLOCK) ON O.OrderKey = OD.OrderKey  
            JOIN WAVEDETAIL WD WITH (NOLOCK) ON OD.OrderKey = WD.OrderKey
            WHERE WD.WaveKey = @c_WaveKey
            AND O.Type NOT IN ( 'M', 'I' )   
            AND O.SOStatus <> 'CANC'   
            AND O.Status < '9'   
            AND (OD.OpenQty - ( OD.QtyAllocated + OD.QtyPreAllocated + OD.QtyPicked )) > 0       
            GROUP BY ISNULL(RTRIM(OD.Storerkey),''),      
                     ISNULL(RTRIM(OD.Sku),''),        
                     ISNULL(RTRIM(O.Facility),''),        
                     ISNULL(RTRIM(O.M_Address4),''),
                     ISNULL(RTRIM(O.Userdefine03),''),                             
                     ISNULL(RTRIM(OD.Lottable01),''),     
                     ISNULL(RTRIM(OD.Lottable02),''),     
                     ISNULL(RTRIM(OD.Lottable03),''),     
                     ISNULL(RTRIM(OD.Lottable06),''),     
                     ISNULL(RTRIM(OD.Lottable07),''),     
                     ISNULL(RTRIM(OD.Lottable08),''),     
                     ISNULL(RTRIM(OD.Lottable09),''),     
                     ISNULL(RTRIM(OD.Lottable10),''),     
                     ISNULL(RTRIM(OD.Lottable11),''),     
                     ISNULL(RTRIM(OD.Lottable12),'')      	
      END 
      
      ----preallocate pallet by order grouping
      IF @n_continue IN(1,2)
      BEGIN
         DECLARE CURSOR_ORDERDET CURSOR LOCAL FAST_FORWARD READ_ONLY FOR        
            SELECT Storerkey,
                   Sku, 
                   Facility,
                   ShipTo,
                   OmniaOrderNo,
                   Lottable01,
                   Lottable02,
                   Lottable03,
                   Lottable06,
                   Lottable07,
                   Lottable08,
                   Lottable09,
                   Lottable10,
                   Lottable11,
                   Lottable12,
                   OrderQty
            FROM #ORDERGROUP
            WHERE OrderQty > 0
            ORDER BY ShipTo,
                     OmniaOrderNo
         
         OPEN CURSOR_ORDERDET           

         FETCH NEXT FROM CURSOR_ORDERDET INTO @c_StorerKey, @c_SKU, @c_Facility, @c_ShipTo, @c_OmniaOrderNo, @c_Lottable01, @c_Lottable02, @c_Lottable03, @c_Lottable06,
                                              @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10, @c_Lottable11, @c_Lottable12, @n_OrderQty

         WHILE (@@FETCH_STATUS <> -1)          
         BEGIN
         	 DECLARE CURSOR_LOTATTRIBUTEQTY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR        
         	    SELECT Lottable05, Qty
         	    FROM #LotattributeAllocated
         	    WHERE Storerkey = @c_Storerkey
         	    AND Sku = @c_Sku
         	    AND Facility = @c_Facility
         	    AND Lottable01 = @c_Lottable01
         	    AND Lottable02 = @c_Lottable02
         	    AND Lottable03 = @c_Lottable03
         	    AND Lottable06 = @c_Lottable06
         	    AND Lottable07 = @c_Lottable07
         	    AND Lottable08 = @c_Lottable08
         	    AND Lottable09 = @c_Lottable09
         	    AND Lottable10 = @c_Lottable10
         	    AND Lottable11 = @c_Lottable11
         	    AND Lottable12 = @c_Lottable12
         	    AND Qty > 0         	    
         	    ORDER BY Lottable05
         	 
            OPEN CURSOR_LOTATTRIBUTEQTY           

            FETCH NEXT FROM CURSOR_LOTATTRIBUTEQTY INTO @d_Lottable05, @n_QtyAvailable
             
            WHILE (@@FETCH_STATUS <> -1) AND @n_OrderQty > 0         
            BEGIN
            	 DELETE FROM #LOTxLOCxID
               SET @c_SQL = N'
                   INSERT INTO #LOTxLOCxID (Loc, LogicalLocation, Lot, ID, Qty, QtyAvailable, QtyReplen)
                   SELECT LOTxLOCxID.Loc, LOC.LogicalLocation, LOTxLOCxID.Lot, ISNULL(LOTxLOCxID.ID,''''), LOTXLOCXID.Qty,
                          (LOTXLOCXID.Qty - LOTXLOCXID.QtyAllocated - LOTXLOCXID.QtyPicked - LOTXLOCXID.QtyReplen) AS QtyAvailable, LOTxLOCxID.QtyReplen
                   FROM LOTxLOCxID WITH (NOLOCK)      
                      JOIN LOC WITH (NOLOCK) ON (LOTxLOCxID.Loc = LOC.LOC)      
                      JOIN ID WITH (NOLOCK) ON (LOTxLOCxID.Id = ID.ID AND ID.STATUS = ''OK'')       
                      JOIN LOT WITH (NOLOCK) ON (LOTXLOCXID.LOT = LOT.LOT AND LOT.STATUS = ''OK'')         
                      JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON LOT.LOT = LA.LOT       
                      LEFT JOIN #IDxLOC_USED IU ON LOTxLOCxID.ID = IU.ID AND LOTxLOCxID.Loc = IU.Loc  
                   WHERE LOC.LocationFlag = ''NONE''       
                      AND LOC.Status = ''OK''       
                      AND LOC.Facility = @c_Facility   
                      AND LOTxLOCxID.STORERKEY = @c_StorerKey
                      AND LOTxLOCxID.SKU = @c_SKU ' + CHAR(13) +
                      CASE WHEN ISNULL(RTRIM(@c_Lottable01),'') = '' THEN '' ELSE ' AND LA.Lottable01 = @c_Lottable01 ' + CHAR(13) END +      
                      CASE WHEN ISNULL(RTRIM(@c_Lottable02),'') = '' THEN '' ELSE ' AND LA.Lottable02 = @c_Lottable02 ' + CHAR(13) END +      
                      CASE WHEN ISNULL(RTRIM(@c_Lottable03),'') = '' THEN '' ELSE ' AND LA.Lottable03 = @c_Lottable03 ' + CHAR(13) END +  
                      CASE WHEN ISNULL(RTRIM(@c_Lottable06),'') = '' THEN '' ELSE ' AND LA.Lottable06 = @c_Lottable06 ' + CHAR(13) END +  
                      CASE WHEN ISNULL(RTRIM(@c_Lottable07),'') = '' THEN '' ELSE ' AND LA.Lottable07 = @c_Lottable07 ' + CHAR(13) END +  
                      CASE WHEN ISNULL(RTRIM(@c_Lottable08),'') = '' THEN '' ELSE ' AND LA.Lottable08 = @c_Lottable08 ' + CHAR(13) END +  
                      CASE WHEN ISNULL(RTRIM(@c_Lottable09),'') = '' THEN '' ELSE ' AND LA.Lottable09 = @c_Lottable09 ' + CHAR(13) END +  
                      CASE WHEN ISNULL(RTRIM(@c_Lottable10),'') = '' THEN '' ELSE ' AND LA.Lottable10 = @c_Lottable10 ' + CHAR(13) END +  
                      CASE WHEN ISNULL(RTRIM(@c_Lottable11),'') = '' THEN '' ELSE ' AND LA.Lottable11 = @c_Lottable11 ' + CHAR(13) END +  
                      CASE WHEN ISNULL(RTRIM(@c_Lottable12),'') = '' THEN '' ELSE ' AND LA.Lottable12 = @c_Lottable12 ' + CHAR(13) END +  
                      'AND (LOTxLOCxID.QTY - LOTXLOCXID.QtyAllocated - LOTXLOCXID.QtyPicked - LOTXLOCXID.QtyReplen)  > 0 
                      AND LOC.LocationType = ''OTHER''
                      AND LOC.LocationCategory = ''BULK''
                      AND LOC.LocationHandling = ''1''
                      AND LA.Lottable05 = @d_Lottable05
                      AND IU.ID IS NULL
                      ORDER BY LOC.LogicalLocation, LOTxLOCxID.Loc, LOTxLOCxID.ID '
                      
               SET @c_SQLParm =  N'@c_Facility NVARCHAR(5), @c_StorerKey NVARCHAR(15), @c_SKU NVARCHAR(20), ' +      
                                 '@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18), ' + 
                                 '@c_Lottable06 NVARCHAR(30), @c_Lottable07 NVARCHAR(30), @c_Lottable08 NVARCHAR(30), ' + 
                                 '@c_Lottable09 NVARCHAR(30), @c_Lottable10 NVARCHAR(30), @c_Lottable11 NVARCHAR(30), ' + 
                                 '@c_Lottable12 NVARCHAR(30), @d_Lottable05 DATETIME' 
                        
               EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_Facility, @c_StorerKey, @c_SKU, @c_Lottable01, @c_Lottable02, @c_Lottable03, 
                                  @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10, @c_Lottable11, @c_Lottable12, @d_Lottable05         	
               
               DELETE FROM #LOTxLOCxID      
               WHERE EXISTS (
                          SELECT LID.ID
                          FROM LOTxLOCxID LID (NOLOCK)
                          JOIN LOC (NOLOCK) ON LID.Loc = LOC.Loc
                          JOIN LOTATTRIBUTE LA (NOLOCK) ON LID.LOT = LA.LOT
                          LEFT JOIN UCC WITH (NOLOCK) ON (LID.LOT = UCC.LOT AND LID.LOC = UCC.LOC AND LID.ID = UCC.ID
                                                          AND UCC.Status > '2' AND UCC.Status < '9')
                          WHERE LID.Storerkey = @c_Storerkey
                          AND LID.ID = #LOTxLOCxID.ID     
                          AND LOC.LocationType = 'OTHER'      
                          AND LOC.LocationCategory = 'BULK'
                          AND LOC.LocationHandling = '1' 
                          GROUP BY LID.ID
                          HAVING COUNT(DISTINCT LA.Lottable05) > 1 OR COUNT(DISTINCT LA.SKU) > 1 OR SUM(LID.QtyAllocated + LID.QtyPicked + LID.QtyReplen) > 0 OR SUM(CASE WHEN ISNULL(UCC.UCCNo,'') <> '' THEN 1 ELSE 0 END) > 0  --Must be same lottable05
                        )      	
                OR #LOTxLOCxID.ID = ''        
         
               DELETE FROM #IDxLOC
               
               --Retrieve sum qty for the pallet and loc
               INSERT INTO #IDxLOC (ID, LOC, QtyAvailable)
               SELECT LLI.ID, LLI.LOC, SUM(LLI.QtyAvailable)
               FROM #LOTxLOCxID LLI
               JOIN LOTATTRIBUTE LA (NOLOCK) ON LLI.Lot = LA.Lot 
               GROUP BY LLI.ID, LLI.LOC, LLI.LogicalLocation
               ORDER BY LLI.LogicalLocation, LLI.Loc, LLI.ID                   
               
               WHILE @n_OrderQty > 0
               BEGIN
                  SELECT TOP 1 @c_ID = ID, @c_Loc = Loc, @n_IDQty = QtyAvailable
                  FROM #IDxLOC            
                  WHERE QtyAvailable <= @n_OrderQty
                  AND QtyAvailable > 0
                  AND QtyAvailable <= @n_QtyAvailable
                  ORDER BY SeqNo
                  
                  IF @@ROWCOUNT = 0
                     BREAK
                  
                  DECLARE CURSOR_IDLOT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
                     SELECT Lot, QtyAvailable
                     FROM #LOTxLOCxID
                     WHERE ID = @c_ID
                     AND LOC = @c_Loc
                                    
                  OPEN CURSOR_IDLOT

                  FETCH NEXT FROM CURSOR_IDLOT INTO @c_Lot, @n_LotQty
             
                  WHILE (@@FETCH_STATUS <> -1)               
                  BEGIN
                  	  IF EXISTS(SELECT 1 FROM ##CARLOT(NOLOCK) WHERE Lot = @c_Lot AND SP_ID = @@SPID)
                  	  BEGIN
                  	     UPDATE ##CARLOT WITH (ROWLOCK)
                  	     SET Qty = Qty + @n_LotQty
                  	     WHERE Lot = @c_Lot
                  	     AND SP_ID = @@SPID
                  	  END
                  	  ELSE
                  	  BEGIN  
                 	       INSERT INTO ##CARLOT (LoT, Qty, QtyAllocated, SP_ID, AddDate)
                 	       VALUES (@c_Lot, @n_LotQty, 0, @@SPID, GetDate())
                 	  END               	              	  
                  	  
                     FETCH NEXT FROM CURSOR_IDLOT INTO @c_Lot, @n_LotQty
                  END
                  CLOSE CURSOR_IDLOT
                  DEALLOCATE CURSOR_IDLOT  
                  
                  UPDATE #LotattributeAllocated
                  SET Qty = Qty - @n_IDQty
         	        WHERE Storerkey = @c_Storerkey
         	        AND Sku = @c_Sku
         	        AND Facility = @c_Facility
         	        AND Lottable01 = @c_Lottable01
         	        AND Lottable02 = @c_Lottable02
         	        AND Lottable03 = @c_Lottable03
         	        AND Lottable06 = @c_Lottable06
         	        AND Lottable07 = @c_Lottable07
         	        AND Lottable08 = @c_Lottable08
         	        AND Lottable09 = @c_Lottable09
         	        AND Lottable10 = @c_Lottable10
         	        AND Lottable11 = @c_Lottable11
         	        AND Lottable12 = @c_Lottable12
         	        AND Lottable05 = @d_Lottable05
         	       
         	        UPDATE #ORDERGROUP
         	        SET OrderQty = OrderQty - @n_IDQty
         	        WHERE Storerkey = @c_Storerkey
         	        AND Sku = @c_Sku
         	        AND Facility = @c_Facility
                  AND Shipto = @c_ShipTo
                  AND OmniaOrderNo = @c_OmniaOrderNo
         	        AND Lottable01 = @c_Lottable01
         	        AND Lottable02 = @c_Lottable02
         	        AND Lottable03 = @c_Lottable03
         	        AND Lottable06 = @c_Lottable06
         	        AND Lottable07 = @c_Lottable07
         	        AND Lottable08 = @c_Lottable08
         	        AND Lottable09 = @c_Lottable09
         	        AND Lottable10 = @c_Lottable10
         	        AND Lottable11 = @c_Lottable11
         	        AND Lottable12 = @c_Lottable12
         	        
         	        INSERT INTO #IDxLOC_USED (ID, Loc, LockType)
         	        VALUES(@c_ID, @c_Loc, 'F')
                  
                  DELETE FROM #IDxLOC WHERE ID = @c_ID AND LOC = @c_Loc
                  SET @n_QtyAvailable = @n_QtyAvailable - @n_IDQty
                  SET @n_OrderQty = @n_OrderQty - @n_IDQty                              	            	
               END     	  
               	  
               FETCH NEXT FROM CURSOR_LOTATTRIBUTEQTY INTO @d_Lottable05, @n_QtyAvailable
            END 
            CLOSE CURSOR_LOTATTRIBUTEQTY
            DEALLOCATE CURSOR_LOTATTRIBUTEQTY      	 
         	  
            FETCH NEXT FROM CURSOR_ORDERDET INTO @c_StorerKey, @c_SKU, @c_Facility, @c_ShipTo, @c_OmniaOrderNo, @c_Lottable01, @c_Lottable02, @c_Lottable03, @c_Lottable06,
                                                 @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10, @c_Lottable11, @c_Lottable12, @n_OrderQty
         END
         CLOSE CURSOR_ORDERDET
         DEALLOCATE CURSOR_ORDERDET                        	              
      END

      ----preallocate carton by order grouping
      IF @n_continue IN(1,2)
      BEGIN
         DECLARE CURSOR_ORDERDET CURSOR LOCAL FAST_FORWARD READ_ONLY FOR        
            SELECT StorerKey, 
                   Sku, 
                   Facility,
                   ShipTo,
                   OmniaOrderNo,
                   Lottable01,
                   Lottable02,
                   Lottable03,
                   Lottable06,
                   Lottable07,
                   Lottable08,
                   Lottable09,
                   Lottable10,
                   Lottable11,
                   Lottable12,
                   OrderQty
            FROM #ORDERGROUP
            WHERE OrderQty > 0
            ORDER BY ShipTo,
                     OmniaOrderNo
         
         OPEN CURSOR_ORDERDET           
             
         FETCH NEXT FROM CURSOR_ORDERDET INTO @c_StorerKey, @c_SKU, @c_Facility, @c_ShipTo, @c_OmniaOrderNo, @c_Lottable01, @c_Lottable02, @c_Lottable03, @c_Lottable06,
                                              @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10, @c_Lottable11, @c_Lottable12, @n_OrderQty
             
         WHILE (@@FETCH_STATUS <> -1)          
         BEGIN
         	 DECLARE CURSOR_LOTATTRIBUTEQTY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR        
         	    SELECT Lottable05, Qty
         	    FROM #LotattributeAllocated
         	    WHERE Storerkey = @c_Storerkey
         	    AND Sku = @c_Sku
         	    AND Facility = @c_Facility
         	    AND Lottable01 = @c_Lottable01
         	    AND Lottable02 = @c_Lottable02
         	    AND Lottable03 = @c_Lottable03
         	    AND Lottable06 = @c_Lottable06
         	    AND Lottable07 = @c_Lottable07
         	    AND Lottable08 = @c_Lottable08
         	    AND Lottable09 = @c_Lottable09
         	    AND Lottable10 = @c_Lottable10
         	    AND Lottable11 = @c_Lottable11
         	    AND Lottable12 = @c_Lottable12
         	    AND Qty > 0
         	    ORDER BY Lottable05
         	 
            OPEN CURSOR_LOTATTRIBUTEQTY           
             
            FETCH NEXT FROM CURSOR_LOTATTRIBUTEQTY INTO @d_Lottable05, @n_QtyAvailable
             
            WHILE (@@FETCH_STATUS <> -1) AND @n_OrderQty > 0         
            BEGIN
               SET @c_SQL = N'
                   DECLARE CURSOR_UCC CURSOR FAST_FORWARD READ_ONLY FOR
                   SELECT LOTxLOCxID.Loc, LOTxLOCxID.Lot, LOTxLOCxID.ID, UCC.Qty, UCC.UCCNo, LOC.LocationHandling
                   FROM LOTxLOCxID WITH (NOLOCK)      
                      JOIN LOC WITH (NOLOCK) ON (LOTxLOCxID.Loc = LOC.LOC)      
                      JOIN ID WITH (NOLOCK) ON (LOTxLOCxID.Id = ID.ID AND ID.STATUS = ''OK'')       
                      JOIN LOT WITH (NOLOCK) ON (LOTXLOCXID.LOT = LOT.LOT AND LOT.STATUS = ''OK'')         
                      JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON LOT.LOT = LA.LOT            
                      JOIN UCC WITH (NOLOCK) ON (UCC.SKU = LOTxLOCxID.SKU AND UCC.LOT = LOT.LOT AND UCC.LOC = LOC.LOC AND UCC.ID = ID.ID AND UCC.Status < ''3'')
                      LEFT JOIN #IDxLOC_USED IU ON LOTxLOCxID.ID = IU.ID AND LOTxLOCxID.Loc = IU.Loc AND IU.LockType = ''F''  
                      LEFT JOIN #UCC_USED UU ON UCC.UCCNo = UU.UCCNo                     
                   WHERE LOC.LocationFlag = ''NONE''       
                      AND LOC.Status = ''OK''       
                      AND LOC.Facility = @c_Facility   
                      AND LOTxLOCxID.STORERKEY = @c_StorerKey
                      AND LOTxLOCxID.SKU = @c_SKU ' + CHAR(13) +
                      CASE WHEN ISNULL(RTRIM(@c_Lottable01),'') = '' THEN '' ELSE ' AND LA.Lottable01 = @c_Lottable01 ' + CHAR(13) END +      
                      CASE WHEN ISNULL(RTRIM(@c_Lottable02),'') = '' THEN '' ELSE ' AND LA.Lottable02 = @c_Lottable02 ' + CHAR(13) END +      
                      CASE WHEN ISNULL(RTRIM(@c_Lottable03),'') = '' THEN '' ELSE ' AND LA.Lottable03 = @c_Lottable03 ' + CHAR(13) END +  
                      CASE WHEN ISNULL(RTRIM(@c_Lottable06),'') = '' THEN '' ELSE ' AND LA.Lottable06 = @c_Lottable06 ' + CHAR(13) END +  
                      CASE WHEN ISNULL(RTRIM(@c_Lottable07),'') = '' THEN '' ELSE ' AND LA.Lottable07 = @c_Lottable07 ' + CHAR(13) END +  
                      CASE WHEN ISNULL(RTRIM(@c_Lottable08),'') = '' THEN '' ELSE ' AND LA.Lottable08 = @c_Lottable08 ' + CHAR(13) END +  
                      CASE WHEN ISNULL(RTRIM(@c_Lottable09),'') = '' THEN '' ELSE ' AND LA.Lottable09 = @c_Lottable09 ' + CHAR(13) END +  
                      CASE WHEN ISNULL(RTRIM(@c_Lottable10),'') = '' THEN '' ELSE ' AND LA.Lottable10 = @c_Lottable10 ' + CHAR(13) END +  
                      CASE WHEN ISNULL(RTRIM(@c_Lottable11),'') = '' THEN '' ELSE ' AND LA.Lottable11 = @c_Lottable11 ' + CHAR(13) END +  
                      CASE WHEN ISNULL(RTRIM(@c_Lottable12),'') = '' THEN '' ELSE ' AND LA.Lottable12 = @c_Lottable12 ' + CHAR(13) END +  
                      'AND (LOTxLOCxID.QTY - LOTXLOCXID.QtyAllocated - LOTXLOCXID.QtyPicked - LOTXLOCXID.QtyReplen)  > 0 
                      AND LOC.LocationType = ''OTHER''
                      AND LOC.LocationCategory = ''BULK''
                      AND LOC.LocationHandling IN(''1'',''2'')
                      AND LA.Lottable05 = @d_Lottable05
                      AND IU.ID IS NULL
                      AND UU.UCCNo IS NULL
                      ORDER BY LOC.LocationHandling DESC, LOC.LogicalLocation, LOTxLOCxID.Loc, LOTxLOCxID.ID '
                      
               SET @c_SQLParm =  N'@c_Facility NVARCHAR(5), @c_StorerKey NVARCHAR(15), @c_SKU NVARCHAR(20), ' +      
                                 '@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18), ' + 
                                 '@c_Lottable06 NVARCHAR(30), @c_Lottable07 NVARCHAR(30), @c_Lottable08 NVARCHAR(30), ' + 
                                 '@c_Lottable09 NVARCHAR(30), @c_Lottable10 NVARCHAR(30), @c_Lottable11 NVARCHAR(30), ' + 
                                 '@c_Lottable12 NVARCHAR(30), @d_Lottable05 DATETIME' 
                        
               EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_Facility, @c_StorerKey, @c_SKU, @c_Lottable01, @c_Lottable02, @c_Lottable03, 
                                  @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10, @c_Lottable11, @c_Lottable12, @d_Lottable05         	
                                  
               OPEN CURSOR_UCC

               FETCH NEXT FROM CURSOR_UCC INTO @c_Loc, @c_Lot, @c_ID, @n_UCCQty, @c_UCCNo, @c_LocationHDL
          
               WHILE (@@FETCH_STATUS <> -1) AND @n_OrderQty > 0 AND @n_QtyAvailable > 0
               BEGIN                
               	  IF @n_OrderQty >= @n_UCCQty AND @n_QtyAvailable >= @n_UCCQty
               	  BEGIN
                     IF EXISTS(SELECT 1 FROM ##CARLOT(NOLOCK) WHERE Lot = @c_Lot AND SP_ID = @@SPID)
                     BEGIN
                        UPDATE ##CARLOT WITH (ROWLOCK)
                        SET Qty = Qty + @n_UCCQty
                        WHERE Lot = @c_Lot
                        AND SP_ID = @@SPID
                     END
                     ELSE
                     BEGIN  
                 	      INSERT INTO ##CARLOT (LoT, Qty, QtyAllocated, SP_ID, AddDate)
                 	      VALUES (@c_Lot, @n_UCCQty, 0, @@SPID, GetDate())
                 	   END  
                 	   
                     UPDATE #LotattributeAllocated
                     SET Qty = Qty - @n_UCCQty
         	           WHERE Storerkey = @c_Storerkey
         	           AND Sku = @c_Sku
         	           AND Facility = @c_Facility
         	           AND Lottable01 = @c_Lottable01
         	           AND Lottable02 = @c_Lottable02
         	           AND Lottable03 = @c_Lottable03
         	           AND Lottable06 = @c_Lottable06
         	           AND Lottable07 = @c_Lottable07
         	           AND Lottable08 = @c_Lottable08
         	           AND Lottable09 = @c_Lottable09
         	           AND Lottable10 = @c_Lottable10
         	           AND Lottable11 = @c_Lottable11
         	           AND Lottable12 = @c_Lottable12
         	           AND Lottable05 = @d_Lottable05
         	           
         	           UPDATE #ORDERGROUP
         	           SET OrderQty = OrderQty - @n_UCCQty
         	           WHERE Storerkey = @c_Storerkey
         	           AND Sku = @c_Sku
         	           AND Facility = @c_Facility
                     AND ShipTo = @c_ShipTo
                     AND OmniaOrderNo = @c_OmniaOrderNo
         	           AND Lottable01 = @c_Lottable01
         	           AND Lottable02 = @c_Lottable02
         	           AND Lottable03 = @c_Lottable03
         	           AND Lottable06 = @c_Lottable06
         	           AND Lottable07 = @c_Lottable07
         	           AND Lottable08 = @c_Lottable08
         	           AND Lottable09 = @c_Lottable09
         	           AND Lottable10 = @c_Lottable10
         	           AND Lottable11 = @c_Lottable11
         	           AND Lottable12 = @c_Lottable12
         	           
         	           IF @c_LocationHDL = '1' --Pallet loc
         	           BEGIN
         	              IF NOT EXISTS(SELECT 1 FROM #IDxLOC_USED WHERE ID = @c_ID AND Loc = @c_Loc)
         	              BEGIN
         	           	     INSERT INTO #IDxLOC_USED (ID, Loc, LockType)
         	                 VALUES(@c_ID, @c_Loc, 'P')
         	              END   
         	           END
         	           
         	           IF NOT EXISTS(SELECT 1 FROM #UCC_USED WHERE UCCNo = @c_UCCNo)
         	           BEGIN
         	           	  INSERT INTO #UCC_USED (UCCNo)
         	           	  VALUES (@c_UCCNo)
         	           END
                 	   
                     SET @n_QtyAvailable = @n_QtyAvailable - @n_UCCQty
                     SET @n_OrderQty = @n_OrderQty - @n_UCCQty                              	            	
                  END             	   
                  ELSE
                     BREAK           	  
               	
                  FETCH NEXT FROM CURSOR_UCC INTO @c_Loc, @c_Lot, @c_ID, @n_UCCQty, @c_UCCNo, @c_LocationHDL
               END
               CLOSE CURSOR_UCC
               DEALLOCATE CURSOR_UCC
                         	                       	  
               FETCH NEXT FROM CURSOR_LOTATTRIBUTEQTY INTO @d_Lottable05, @n_QtyAvailable
            END 
            CLOSE CURSOR_LOTATTRIBUTEQTY
            DEALLOCATE CURSOR_LOTATTRIBUTEQTY      	 
         	
            FETCH NEXT FROM CURSOR_ORDERDET INTO @c_StorerKey, @c_SKU, @c_Facility, @c_ShipTo, @c_OmniaOrderNo, @c_Lottable01, @c_Lottable02, @c_Lottable03, @c_Lottable06,
                                                 @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10, @c_Lottable11, @c_Lottable12, @n_OrderQty
         END
         CLOSE CURSOR_ORDERDET
         DEALLOCATE CURSOR_ORDERDET                        	              
      END

      ----preallocate pallet by Conso order
      IF @n_continue IN(1,2)
      BEGIN
         DECLARE CURSOR_ORDERDET CURSOR LOCAL FAST_FORWARD READ_ONLY FOR        
            SELECT StorerKey, 
                   Sku, 
                   Facility,
                   Lottable01,
                   Lottable02,
                   Lottable03,
                   Lottable06,
                   Lottable07,
                   Lottable08,
                   Lottable09,
                   Lottable10,
                   Lottable11,
                   Lottable12,
                   SUM(OrderQty)
            FROM #ORDERGROUP
            WHERE OrderQty > 0
            GROUP BY Storerkey,
                     Sku, 
                     Facility,
                     Lottable01,
                     Lottable02,
                     Lottable03,
                     Lottable06,
                     Lottable07,
                     Lottable08,
                     Lottable09,
                     Lottable10,
                     Lottable11,
                     Lottable12
            ORDER BY Sku
         
         OPEN CURSOR_ORDERDET           
             
         FETCH NEXT FROM CURSOR_ORDERDET INTO @c_StorerKey, @c_SKU, @c_Facility, @c_Lottable01, @c_Lottable02, @c_Lottable03, @c_Lottable06,
                                              @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10, @c_Lottable11, @c_Lottable12, @n_OrderQty
             
         WHILE (@@FETCH_STATUS <> -1)          
         BEGIN
         	 DECLARE CURSOR_LOTATTRIBUTEQTY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR        
         	    SELECT Lottable05, Qty
         	    FROM #LotattributeAllocated
         	    WHERE Storerkey = @c_Storerkey
         	    AND Sku = @c_Sku
         	    AND Facility = @c_Facility
         	    AND Lottable01 = @c_Lottable01
         	    AND Lottable02 = @c_Lottable02
         	    AND Lottable03 = @c_Lottable03
         	    AND Lottable06 = @c_Lottable06
         	    AND Lottable07 = @c_Lottable07
         	    AND Lottable08 = @c_Lottable08
         	    AND Lottable09 = @c_Lottable09
         	    AND Lottable10 = @c_Lottable10
         	    AND Lottable11 = @c_Lottable11
         	    AND Lottable12 = @c_Lottable12
         	    AND Qty > 0         	    
         	    ORDER BY Lottable05
         	 
            OPEN CURSOR_LOTATTRIBUTEQTY           
             
            FETCH NEXT FROM CURSOR_LOTATTRIBUTEQTY INTO @d_Lottable05, @n_QtyAvailable
             
            WHILE (@@FETCH_STATUS <> -1) AND @n_OrderQty > 0         
            BEGIN
            	 DELETE FROM #LOTxLOCxID
               SET @c_SQL = N'
                   INSERT INTO #LOTxLOCxID (Loc, LogicalLocation, Lot, ID, Qty, QtyAvailable, QtyReplen)
                   SELECT LOTxLOCxID.Loc, LOC.LogicalLocation, LOTxLOCxID.Lot, ISNULL(LOTxLOCxID.ID,''''), LOTXLOCXID.Qty,
                          (LOTXLOCXID.Qty - LOTXLOCXID.QtyAllocated - LOTXLOCXID.QtyPicked - LOTXLOCXID.QtyReplen) AS QtyAvailable, LOTxLOCxID.QtyReplen
                   FROM LOTxLOCxID WITH (NOLOCK)      
                      JOIN LOC WITH (NOLOCK) ON (LOTxLOCxID.Loc = LOC.LOC)      
                      JOIN ID WITH (NOLOCK) ON (LOTxLOCxID.Id = ID.ID AND ID.STATUS = ''OK'')       
                      JOIN LOT WITH (NOLOCK) ON (LOTXLOCXID.LOT = LOT.LOT AND LOT.STATUS = ''OK'')         
                      JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON LOT.LOT = LA.LOT       
                      LEFT JOIN #IDxLOC_USED IU ON LOTxLOCxID.ID = IU.ID AND LOTxLOCxID.Loc = IU.Loc  
                   WHERE LOC.LocationFlag = ''NONE''       
                      AND LOC.Status = ''OK''       
                      AND LOC.Facility = @c_Facility   
                      AND LOTxLOCxID.STORERKEY = @c_StorerKey
                      AND LOTxLOCxID.SKU = @c_SKU ' + CHAR(13) +
                      CASE WHEN ISNULL(RTRIM(@c_Lottable01),'') = '' THEN '' ELSE ' AND LA.Lottable01 = @c_Lottable01 ' + CHAR(13) END +      
                      CASE WHEN ISNULL(RTRIM(@c_Lottable02),'') = '' THEN '' ELSE ' AND LA.Lottable02 = @c_Lottable02 ' + CHAR(13) END +      
                      CASE WHEN ISNULL(RTRIM(@c_Lottable03),'') = '' THEN '' ELSE ' AND LA.Lottable03 = @c_Lottable03 ' + CHAR(13) END +  
                      CASE WHEN ISNULL(RTRIM(@c_Lottable06),'') = '' THEN '' ELSE ' AND LA.Lottable06 = @c_Lottable06 ' + CHAR(13) END +  
                      CASE WHEN ISNULL(RTRIM(@c_Lottable07),'') = '' THEN '' ELSE ' AND LA.Lottable07 = @c_Lottable07 ' + CHAR(13) END +  
                      CASE WHEN ISNULL(RTRIM(@c_Lottable08),'') = '' THEN '' ELSE ' AND LA.Lottable08 = @c_Lottable08 ' + CHAR(13) END +  
                      CASE WHEN ISNULL(RTRIM(@c_Lottable09),'') = '' THEN '' ELSE ' AND LA.Lottable09 = @c_Lottable09 ' + CHAR(13) END +  
                      CASE WHEN ISNULL(RTRIM(@c_Lottable10),'') = '' THEN '' ELSE ' AND LA.Lottable10 = @c_Lottable10 ' + CHAR(13) END +  
                      CASE WHEN ISNULL(RTRIM(@c_Lottable11),'') = '' THEN '' ELSE ' AND LA.Lottable11 = @c_Lottable11 ' + CHAR(13) END +  
                      CASE WHEN ISNULL(RTRIM(@c_Lottable12),'') = '' THEN '' ELSE ' AND LA.Lottable12 = @c_Lottable12 ' + CHAR(13) END +  
                      'AND (LOTxLOCxID.QTY - LOTXLOCXID.QtyAllocated - LOTXLOCXID.QtyPicked - LOTXLOCXID.QtyReplen)  > 0 
                      AND LOC.LocationType = ''OTHER''
                      AND LOC.LocationCategory = ''BULK''
                      AND LOC.LocationHandling = ''1''
                      AND LA.Lottable05 = @d_Lottable05
                      AND IU.ID IS NULL
                      ORDER BY LOC.LogicalLocation, LOTxLOCxID.Loc, LOTxLOCxID.ID '
                      
               SET @c_SQLParm =  N'@c_Facility NVARCHAR(5), @c_StorerKey NVARCHAR(15), @c_SKU NVARCHAR(20), ' +      
                                 '@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18), ' + 
                                 '@c_Lottable06 NVARCHAR(30), @c_Lottable07 NVARCHAR(30), @c_Lottable08 NVARCHAR(30), ' + 
                                 '@c_Lottable09 NVARCHAR(30), @c_Lottable10 NVARCHAR(30), @c_Lottable11 NVARCHAR(30), ' + 
                                 '@c_Lottable12 NVARCHAR(30), @d_Lottable05 DATETIME' 
                        
               EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_Facility, @c_StorerKey, @c_SKU, @c_Lottable01, @c_Lottable02, @c_Lottable03, 
                                  @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10, @c_Lottable11, @c_Lottable12, @d_Lottable05         	
         
               DELETE FROM #LOTxLOCxID      
               WHERE EXISTS (
                          SELECT LID.ID
                          FROM LOTxLOCxID LID (NOLOCK)
                          JOIN LOC (NOLOCK) ON LID.Loc = LOC.Loc
                          JOIN LOTATTRIBUTE LA (NOLOCK) ON LID.LOT = LA.LOT
                          LEFT JOIN UCC WITH (NOLOCK) ON (LID.LOT = UCC.LOT AND LID.LOC = UCC.LOC AND LID.ID = UCC.ID
                                                          AND UCC.Status > '2' AND UCC.Status < '9')
                          WHERE LID.Storerkey = @c_Storerkey
                          AND LID.ID = #LOTxLOCxID.ID     
                          AND LOC.LocationType = 'OTHER'      
                          AND LOC.LocationCategory = 'BULK'
                          AND LOC.LocationHandling = '1' 
                          GROUP BY LID.ID
                          HAVING COUNT(DISTINCT LA.Lottable05) > 1 OR COUNT(DISTINCT LA.SKU) > 1 OR SUM(LID.QtyAllocated + LID.QtyPicked + LID.QtyReplen) > 0 OR SUM(CASE WHEN ISNULL(UCC.UCCNo,'') <> '' THEN 1 ELSE 0 END) > 0  --Must be same lottable05
                        )      	
                OR #LOTxLOCxID.ID = ''        
         
               DELETE FROM #IDxLOC
               
               --Retrieve sum qty for the pallet and loc
               INSERT INTO #IDxLOC (ID, LOC, QtyAvailable)
               SELECT LLI.ID, LLI.LOC, SUM(LLI.QtyAvailable)
               FROM #LOTxLOCxID LLI
               JOIN LOTATTRIBUTE LA (NOLOCK) ON LLI.Lot = LA.Lot 
               GROUP BY LLI.ID, LLI.LOC, LLI.LogicalLocation
               ORDER BY LLI.LogicalLocation, LLI.Loc, LLI.ID                   
               
               WHILE @n_OrderQty > 0
               BEGIN
                  SELECT TOP 1 @c_ID = ID, @c_Loc = Loc, @n_IDQty = QtyAvailable
                  FROM #IDxLOC            
                  WHERE QtyAvailable <= @n_OrderQty
                  AND QtyAvailable > 0
                  AND QtyAvailable <= @n_QtyAvailable
                  ORDER BY SeqNo
                  
                  IF @@ROWCOUNT = 0
                     BREAK
                  
                  DECLARE CURSOR_IDLOT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
                     SELECT Lot, QtyAvailable
                     FROM #LOTxLOCxID
                     WHERE ID = @c_ID
                     AND LOC = @c_Loc
                                    
                  OPEN CURSOR_IDLOT
                  
                  FETCH NEXT FROM CURSOR_IDLOT INTO @c_Lot, @n_LotQty
             
                  WHILE (@@FETCH_STATUS <> -1)               
                  BEGIN
                  	  IF EXISTS(SELECT 1 FROM ##CARLOT(NOLOCK) WHERE Lot = @c_Lot AND SP_ID = @@SPID)
                  	  BEGIN
                  	     UPDATE ##CARLOT WITH (ROWLOCK)
                  	     SET Qty = Qty + @n_LotQty
                  	     WHERE Lot = @c_Lot
                  	     AND SP_ID = @@SPID
                  	  END
                  	  ELSE
                  	  BEGIN  
                 	       INSERT INTO ##CARLOT (LoT, Qty, QtyAllocated, SP_ID, AddDate)
                 	       VALUES (@c_Lot, @n_LotQty, 0, @@SPID, GetDate())
                 	  END               	              	  
                  	  
                     FETCH NEXT FROM CURSOR_IDLOT INTO @c_Lot, @n_LotQty
                  END
                  CLOSE CURSOR_IDLOT
                  DEALLOCATE CURSOR_IDLOT  

                  SET @n_QtyAvailable = @n_QtyAvailable - @n_IDQty
                  SET @n_OrderQty = @n_OrderQty - @n_IDQty                              	            	
                  
                  UPDATE #LotattributeAllocated
                  SET Qty = Qty - @n_IDQty
         	        WHERE Storerkey = @c_Storerkey
         	        AND Sku = @c_Sku
         	        AND Facility = @c_Facility
         	        AND Lottable01 = @c_Lottable01
         	        AND Lottable02 = @c_Lottable02
         	        AND Lottable03 = @c_Lottable03
         	        AND Lottable06 = @c_Lottable06
         	        AND Lottable07 = @c_Lottable07
         	        AND Lottable08 = @c_Lottable08
         	        AND Lottable09 = @c_Lottable09
         	        AND Lottable10 = @c_Lottable10
         	        AND Lottable11 = @c_Lottable11
         	        AND Lottable12 = @c_Lottable12
         	        AND Lottable05 = @d_Lottable05
         	                 	        
         	        DECLARE CURSOR_ORDGRP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
         	           SELECT SeqNo, OrderQty
         	           FROM #ORDERGROUP
         	           WHERE Storerkey = @c_Storerkey
         	           AND Sku = @c_Sku
         	           AND Facility = @c_Facility
         	           AND Lottable01 = @c_Lottable01
         	           AND Lottable02 = @c_Lottable02
         	           AND Lottable03 = @c_Lottable03
         	           AND Lottable06 = @c_Lottable06
         	           AND Lottable07 = @c_Lottable07
         	           AND Lottable08 = @c_Lottable08
         	           AND Lottable09 = @c_Lottable09
         	           AND Lottable10 = @c_Lottable10
         	           AND Lottable11 = @c_Lottable11
         	           AND Lottable12 = @c_Lottable12
         	           ORDER BY SeqNo
         	        
         	        OPEN CURSOR_ORDGRP
         	        
                  FETCH NEXT FROM CURSOR_ORDGRP INTO @n_SeqNo, @n_Qty
             
                  WHILE (@@FETCH_STATUS <> -1) AND @n_IDQty > 0               
                  BEGIN
                  	 IF @n_IDQty >= @n_Qty
                  	    SET @n_UpdateQty = @n_Qty
                  	 ELSE
                  	    SET @n_UpdateQty = @n_IDQty

         	           UPDATE #ORDERGROUP
         	           SET OrderQty = OrderQty - @n_UpdateQty
         	           WHERE Storerkey = @c_Storerkey
         	           AND Sku = @c_Sku
         	           AND Facility = @c_Facility
         	           AND Lottable01 = @c_Lottable01
         	           AND Lottable02 = @c_Lottable02
         	           AND Lottable03 = @c_Lottable03
         	           AND Lottable06 = @c_Lottable06
         	           AND Lottable07 = @c_Lottable07
         	           AND Lottable08 = @c_Lottable08
         	           AND Lottable09 = @c_Lottable09
         	           AND Lottable10 = @c_Lottable10
         	           AND Lottable11 = @c_Lottable11
         	           AND Lottable12 = @c_Lottable12
         	           AND SeqNo = @n_SeqNo
                  	  
                  	 SET @n_IDQty = @n_IDQty - @n_UpdateQty
                  	    
                     FETCH NEXT FROM CURSOR_ORDGRP INTO @n_SeqNo, @n_Qty
                  END
                  CLOSE CURSOR_ORDGRP
                  DEALLOCATE CURSOR_ORDGRP
         	                  	                	        
         	        INSERT INTO #IDxLOC_USED (ID, Loc, LockType)
         	        VALUES(@c_ID, @c_Loc, 'F')
                  
                  DELETE FROM #IDxLOC WHERE ID = @c_ID AND LOC = @c_Loc
               END     	  
               	  
               FETCH NEXT FROM CURSOR_LOTATTRIBUTEQTY INTO @d_Lottable05, @n_QtyAvailable
            END 
            CLOSE CURSOR_LOTATTRIBUTEQTY
            DEALLOCATE CURSOR_LOTATTRIBUTEQTY      	 
         	
            FETCH NEXT FROM CURSOR_ORDERDET INTO @c_StorerKey, @c_SKU, @c_Facility, @c_Lottable01, @c_Lottable02, @c_Lottable03, @c_Lottable06,
                                                 @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10, @c_Lottable11, @c_Lottable12, @n_OrderQty
         END
         CLOSE CURSOR_ORDERDET
         DEALLOCATE CURSOR_ORDERDET                        	              
      END

      ----preallocate carton by Conso order
      IF @n_continue IN(1,2)
      BEGIN
         DECLARE CURSOR_ORDERDET CURSOR LOCAL FAST_FORWARD READ_ONLY FOR        
            SELECT StorerKey, 
                   Sku, 
                   Facility,
                   Lottable01,
                   Lottable02,
                   Lottable03,
                   Lottable06,
                   Lottable07,
                   Lottable08,
                   Lottable09,
                   Lottable10,
                   Lottable11,
                   Lottable12,
                   SUM(OrderQty)
            FROM #ORDERGROUP
            WHERE OrderQty > 0
            GROUP BY Storerkey,
                     Sku, 
                     Facility,
                     Lottable01,
                     Lottable02,
                     Lottable03,
                     Lottable06,
                     Lottable07,
                     Lottable08,
                     Lottable09,
                     Lottable10,
                     Lottable11,
                     Lottable12
            ORDER BY Sku
         
         OPEN CURSOR_ORDERDET           
             
         FETCH NEXT FROM CURSOR_ORDERDET INTO @c_StorerKey, @c_SKU, @c_Facility, @c_Lottable01, @c_Lottable02, @c_Lottable03, @c_Lottable06,
                                              @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10, @c_Lottable11, @c_Lottable12, @n_OrderQty
             
         WHILE (@@FETCH_STATUS <> -1)          
         BEGIN
         	 DECLARE CURSOR_LOTATTRIBUTEQTY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR        
         	    SELECT Lottable05, Qty
         	    FROM #LotattributeAllocated
         	    WHERE Storerkey = @c_Storerkey
         	    AND Sku = @c_Sku
         	    AND Facility = @c_Facility
         	    AND Lottable01 = @c_Lottable01
         	    AND Lottable02 = @c_Lottable02
         	    AND Lottable03 = @c_Lottable03
         	    AND Lottable06 = @c_Lottable06
         	    AND Lottable07 = @c_Lottable07
         	    AND Lottable08 = @c_Lottable08
         	    AND Lottable09 = @c_Lottable09
         	    AND Lottable10 = @c_Lottable10
         	    AND Lottable11 = @c_Lottable11
         	    AND Lottable12 = @c_Lottable12
         	    AND Qty > 0
         	    ORDER BY Lottable05
         	 
            OPEN CURSOR_LOTATTRIBUTEQTY           
             
            FETCH NEXT FROM CURSOR_LOTATTRIBUTEQTY INTO @d_Lottable05, @n_QtyAvailable
             
            WHILE (@@FETCH_STATUS <> -1) AND @n_OrderQty > 0         
            BEGIN
               SET @c_SQL = N'
                   DECLARE CURSOR_UCC CURSOR FAST_FORWARD READ_ONLY FOR
                   SELECT LOTxLOCxID.Loc, LOTxLOCxID.Lot, LOTxLOCxID.ID, UCC.Qty, UCC.UCCNo, LOC.LocationHandling
                   FROM LOTxLOCxID WITH (NOLOCK)      
                      JOIN LOC WITH (NOLOCK) ON (LOTxLOCxID.Loc = LOC.LOC)      
                      JOIN ID WITH (NOLOCK) ON (LOTxLOCxID.Id = ID.ID AND ID.STATUS = ''OK'')       
                      JOIN LOT WITH (NOLOCK) ON (LOTXLOCXID.LOT = LOT.LOT AND LOT.STATUS = ''OK'')         
                      JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON LOT.LOT = LA.LOT            
                      JOIN UCC WITH (NOLOCK) ON (UCC.SKU = LOTxLOCxID.SKU AND UCC.LOT = LOT.LOT AND UCC.LOC = LOC.LOC AND UCC.ID = ID.ID AND UCC.Status < ''3'')
                      LEFT JOIN #IDxLOC_USED IU ON LOTxLOCxID.ID = IU.ID AND LOTxLOCxID.Loc = IU.Loc AND IU.LockType = ''F''  
                      LEFT JOIN #UCC_USED UU ON UCC.UCCNo = UU.UCCNo                     
                   WHERE LOC.LocationFlag = ''NONE''       
                      AND LOC.Status = ''OK''       
                      AND LOC.Facility = @c_Facility   
                      AND LOTxLOCxID.STORERKEY = @c_StorerKey
                      AND LOTxLOCxID.SKU = @c_SKU ' + CHAR(13) +
                      CASE WHEN ISNULL(RTRIM(@c_Lottable01),'') = '' THEN '' ELSE ' AND LA.Lottable01 = @c_Lottable01 ' + CHAR(13) END +      
                      CASE WHEN ISNULL(RTRIM(@c_Lottable02),'') = '' THEN '' ELSE ' AND LA.Lottable02 = @c_Lottable02 ' + CHAR(13) END +      
                      CASE WHEN ISNULL(RTRIM(@c_Lottable03),'') = '' THEN '' ELSE ' AND LA.Lottable03 = @c_Lottable03 ' + CHAR(13) END +  
                      CASE WHEN ISNULL(RTRIM(@c_Lottable06),'') = '' THEN '' ELSE ' AND LA.Lottable06 = @c_Lottable06 ' + CHAR(13) END +  
                      CASE WHEN ISNULL(RTRIM(@c_Lottable07),'') = '' THEN '' ELSE ' AND LA.Lottable07 = @c_Lottable07 ' + CHAR(13) END +  
                      CASE WHEN ISNULL(RTRIM(@c_Lottable08),'') = '' THEN '' ELSE ' AND LA.Lottable08 = @c_Lottable08 ' + CHAR(13) END +  
                      CASE WHEN ISNULL(RTRIM(@c_Lottable09),'') = '' THEN '' ELSE ' AND LA.Lottable09 = @c_Lottable09 ' + CHAR(13) END +  
                      CASE WHEN ISNULL(RTRIM(@c_Lottable10),'') = '' THEN '' ELSE ' AND LA.Lottable10 = @c_Lottable10 ' + CHAR(13) END +  
                      CASE WHEN ISNULL(RTRIM(@c_Lottable11),'') = '' THEN '' ELSE ' AND LA.Lottable11 = @c_Lottable11 ' + CHAR(13) END +  
                      CASE WHEN ISNULL(RTRIM(@c_Lottable12),'') = '' THEN '' ELSE ' AND LA.Lottable12 = @c_Lottable12 ' + CHAR(13) END +  
                      'AND (LOTxLOCxID.QTY - LOTXLOCXID.QtyAllocated - LOTXLOCXID.QtyPicked - LOTXLOCXID.QtyReplen)  > 0 
                      AND LOC.LocationType = ''OTHER''
                      AND LOC.LocationCategory = ''BULK''
                      AND LOC.LocationHandling IN(''1'',''2'')
                      AND LA.Lottable05 = @d_Lottable05
                      AND IU.ID IS NULL
                      AND UU.UCCNo IS NULL
                      ORDER BY LOC.LocationHandling DESC, LOC.LogicalLocation, LOTxLOCxID.Loc, LOTxLOCxID.ID '
                      
               SET @c_SQLParm =  N'@c_Facility NVARCHAR(5), @c_StorerKey NVARCHAR(15), @c_SKU NVARCHAR(20), ' +      
                                 '@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18), ' + 
                                 '@c_Lottable06 NVARCHAR(30), @c_Lottable07 NVARCHAR(30), @c_Lottable08 NVARCHAR(30), ' + 
                                 '@c_Lottable09 NVARCHAR(30), @c_Lottable10 NVARCHAR(30), @c_Lottable11 NVARCHAR(30), ' + 
                                 '@c_Lottable12 NVARCHAR(30), @d_Lottable05 DATETIME' 
                        
               EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_Facility, @c_StorerKey, @c_SKU, @c_Lottable01, @c_Lottable02, @c_Lottable03, 
                                  @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10, @c_Lottable11, @c_Lottable12, @d_Lottable05         	
                                  
               OPEN CURSOR_UCC

               FETCH NEXT FROM CURSOR_UCC INTO @c_Loc, @c_Lot, @c_ID, @n_UCCQty, @c_UCCNo, @c_LocationHDL
          
               WHILE (@@FETCH_STATUS <> -1) AND @n_OrderQty > 0 AND @n_QtyAvailable > 0
               BEGIN                
               	  IF @n_OrderQty >= @n_UCCQty AND @n_QtyAvailable >= @n_UCCQty
               	  BEGIN
                     IF EXISTS(SELECT 1 FROM ##CARLOT(NOLOCK) WHERE Lot = @c_Lot AND SP_ID = @@SPID)
                     BEGIN
                        UPDATE ##CARLOT WITH (ROWLOCK)
                        SET Qty = Qty + @n_UCCQty
                        WHERE Lot = @c_Lot
                        AND SP_ID = @@SPID
                     END
                     ELSE
                     BEGIN  
                 	      INSERT INTO ##CARLOT (LoT, Qty, QtyAllocated, SP_ID, AddDate)
                 	      VALUES (@c_Lot, @n_UCCQty, 0, @@SPID, GetDate())
                 	   END  

                     SET @n_QtyAvailable = @n_QtyAvailable - @n_UCCQty
                     SET @n_OrderQty = @n_OrderQty - @n_UCCQty                              	            	
                 	   
                     UPDATE #LotattributeAllocated
                     SET Qty = Qty - @n_UCCQty
         	           WHERE Storerkey = @c_Storerkey
         	           AND Sku = @c_Sku
         	           AND Facility = @c_Facility
         	           AND Lottable01 = @c_Lottable01
         	           AND Lottable02 = @c_Lottable02
         	           AND Lottable03 = @c_Lottable03
         	           AND Lottable06 = @c_Lottable06
         	           AND Lottable07 = @c_Lottable07
         	           AND Lottable08 = @c_Lottable08
         	           AND Lottable09 = @c_Lottable09
         	           AND Lottable10 = @c_Lottable10
         	           AND Lottable11 = @c_Lottable11
         	           AND Lottable12 = @c_Lottable12
         	           AND Lottable05 = @d_Lottable05

         	           DECLARE CURSOR_ORDGRP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
         	              SELECT SeqNo, OrderQty
         	              FROM #ORDERGROUP
         	              WHERE Storerkey = @c_Storerkey
         	              AND Sku = @c_Sku
         	              AND Facility = @c_Facility
         	              AND Lottable01 = @c_Lottable01
         	              AND Lottable02 = @c_Lottable02
         	              AND Lottable03 = @c_Lottable03
         	              AND Lottable06 = @c_Lottable06
         	              AND Lottable07 = @c_Lottable07
         	              AND Lottable08 = @c_Lottable08
         	              AND Lottable09 = @c_Lottable09
         	              AND Lottable10 = @c_Lottable10
         	              AND Lottable11 = @c_Lottable11
         	              AND Lottable12 = @c_Lottable12
         	              ORDER BY SeqNo
         	           
         	           OPEN CURSOR_ORDGRP
         	           
                     FETCH NEXT FROM CURSOR_ORDGRP INTO @n_SeqNo, @n_Qty
                     
                     WHILE (@@FETCH_STATUS <> -1) AND @n_UCCQty > 0               
                     BEGIN
                     	 IF @n_UCCQty >= @n_Qty
                     	    SET @n_UpdateQty = @n_Qty
                     	 ELSE
                     	    SET @n_UpdateQty = @n_UCCQty
                     
         	              UPDATE #ORDERGROUP
         	              SET OrderQty = OrderQty - @n_UpdateQty
         	              WHERE Storerkey = @c_Storerkey
         	              AND Sku = @c_Sku
         	              AND Facility = @c_Facility
         	              AND Lottable01 = @c_Lottable01
         	              AND Lottable02 = @c_Lottable02
         	              AND Lottable03 = @c_Lottable03
         	              AND Lottable06 = @c_Lottable06
         	              AND Lottable07 = @c_Lottable07
         	              AND Lottable08 = @c_Lottable08
         	              AND Lottable09 = @c_Lottable09
         	              AND Lottable10 = @c_Lottable10
         	              AND Lottable11 = @c_Lottable11
         	              AND Lottable12 = @c_Lottable12
         	              AND SeqNo = @n_SeqNo
                     	  
                     	  SET @n_UCCQty = @n_UCCQty - @n_UpdateQty
                     	    
                        FETCH NEXT FROM CURSOR_ORDGRP INTO @n_SeqNo, @n_Qty
                     END
                     CLOSE CURSOR_ORDGRP
                     DEALLOCATE CURSOR_ORDGRP
         	                   	           
         	           IF @c_LocationHDL = '1' --Pallet loc
         	           BEGIN
         	              IF NOT EXISTS(SELECT 1 FROM #IDxLOC_USED WHERE ID = @c_ID AND Loc = @c_Loc)
         	              BEGIN
         	           	     INSERT INTO #IDxLOC_USED (ID, Loc, LockType)
         	                 VALUES(@c_ID, @c_Loc, 'P')
         	              END   
         	           END
         	           
         	           IF NOT EXISTS(SELECT 1 FROM #UCC_USED WHERE UCCNo = @c_UCCNo)
         	           BEGIN
         	           	  INSERT INTO #UCC_USED (UCCNo)
         	           	  VALUES (@c_UCCNo)
         	           END                 	   
                  END             	   
                  ELSE
                     BREAK           	  
               	
                  FETCH NEXT FROM CURSOR_UCC INTO @c_Loc, @c_Lot, @c_ID, @n_UCCQty, @c_UCCNo, @c_LocationHDL
               END
               CLOSE CURSOR_UCC
               DEALLOCATE CURSOR_UCC
                         	                       	  
               FETCH NEXT FROM CURSOR_LOTATTRIBUTEQTY INTO @d_Lottable05, @n_QtyAvailable
            END 
            CLOSE CURSOR_LOTATTRIBUTEQTY
            DEALLOCATE CURSOR_LOTATTRIBUTEQTY      	 
         	
            FETCH NEXT FROM CURSOR_ORDERDET INTO @c_StorerKey, @c_SKU, @c_Facility, @c_Lottable01, @c_Lottable02, @c_Lottable03, @c_Lottable06,
                                                 @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10, @c_Lottable11, @c_Lottable12, @n_OrderQty
         END
         CLOSE CURSOR_ORDERDET
         DEALLOCATE CURSOR_ORDERDET                        	              
      END

      ----preallocate piece from pick loc,case loc,bulk loc
      IF @n_continue IN(1,2)
      BEGIN
         DECLARE CURSOR_ORDERDET CURSOR LOCAL FAST_FORWARD READ_ONLY FOR        
            SELECT Storerkey,
                   Sku, 
                   Facility,
                   Lottable01,
                   Lottable02,
                   Lottable03,
                   Lottable06,
                   Lottable07,
                   Lottable08,
                   Lottable09,
                   Lottable10,
                   Lottable11,
                   Lottable12,
                   SUM(OrderQty)
            FROM #ORDERGROUP
            WHERE OrderQty > 0
            GROUP BY Storerkey,
                     Sku, 
                     Facility,
                     Lottable01,
                     Lottable02,
                     Lottable03,
                     Lottable06,
                     Lottable07,
                     Lottable08,
                     Lottable09,
                     Lottable10,
                     Lottable11,
                     Lottable12
            ORDER BY Sku
         
         OPEN CURSOR_ORDERDET           
             
         FETCH NEXT FROM CURSOR_ORDERDET INTO @c_StorerKey, @c_SKU, @c_Facility, @c_Lottable01, @c_Lottable02, @c_Lottable03, @c_Lottable06,
                                              @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10, @c_Lottable11, @c_Lottable12, @n_OrderQty
             
         WHILE (@@FETCH_STATUS <> -1)          
         BEGIN
         	 DECLARE CURSOR_LOTATTRIBUTEQTY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR        
         	    SELECT Lottable05, Qty
         	    FROM #LotattributeAllocated
         	    WHERE Storerkey = @c_Storerkey
         	    AND Sku = @c_Sku
         	    AND Facility = @c_Facility
         	    AND Lottable01 = @c_Lottable01
         	    AND Lottable02 = @c_Lottable02
         	    AND Lottable03 = @c_Lottable03
         	    AND Lottable06 = @c_Lottable06
         	    AND Lottable07 = @c_Lottable07
         	    AND Lottable08 = @c_Lottable08
         	    AND Lottable09 = @c_Lottable09
         	    AND Lottable10 = @c_Lottable10
         	    AND Lottable11 = @c_Lottable11
         	    AND Lottable12 = @c_Lottable12
         	    AND Qty > 0
         	    ORDER BY Lottable05
         	 
            OPEN CURSOR_LOTATTRIBUTEQTY           
             
            FETCH NEXT FROM CURSOR_LOTATTRIBUTEQTY INTO @d_Lottable05, @n_QtyAvailable
             
            WHILE (@@FETCH_STATUS <> -1) AND @n_OrderQty > 0         
            BEGIN
               IF (SELECT CURSOR_STATUS('GLOBAL','CURSOR_LOT2')) >=0 
               BEGIN
                  CLOSE CURSOR_LOT2           
                  DEALLOCATE CURSOR_LOT2      
               END  
            	
               SET @c_SQL = N'
                   DECLARE CURSOR_LOT2 CURSOR FAST_FORWARD READ_ONLY FOR
                   SELECT LOTxLOCxID.Lot, 
                   SUM(LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen) - ISNULL(##CARLOT.Qty,0)
                   FROM LOTxLOCxID WITH (NOLOCK)      
                      JOIN LOC WITH (NOLOCK) ON (LOTxLOCxID.Loc = LOC.LOC)      
                      JOIN ID WITH (NOLOCK) ON (LOTxLOCxID.Id = ID.ID AND ID.STATUS = ''OK'')       
                      JOIN LOT WITH (NOLOCK) ON (LOTXLOCXID.LOT = LOT.LOT AND LOT.STATUS = ''OK'')         
                      JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON LOT.LOT = LA.LOT
                      LEFT JOIN ##CARLOT (NOLOCK) ON LOTxLOCxID.Lot = ##CARLOT.Lot AND ##CARLOT.SP_ID = @@SPID             
                   WHERE LOC.LocationFlag = ''NONE''       
                      AND LOC.Status = ''OK''       
                      AND LOC.Facility = @c_Facility   
                      AND LOTxLOCxID.STORERKEY = @c_StorerKey
                      AND LOTxLOCxID.SKU = @c_SKU ' + CHAR(13) +
                      CASE WHEN ISNULL(RTRIM(@c_Lottable01),'') = '' THEN '' ELSE ' AND LA.Lottable01 = @c_Lottable01 ' + CHAR(13) END +      
                      CASE WHEN ISNULL(RTRIM(@c_Lottable02),'') = '' THEN '' ELSE ' AND LA.Lottable02 = @c_Lottable02 ' + CHAR(13) END +      
                      CASE WHEN ISNULL(RTRIM(@c_Lottable03),'') = '' THEN '' ELSE ' AND LA.Lottable03 = @c_Lottable03 ' + CHAR(13) END +  
                      CASE WHEN ISNULL(RTRIM(@c_Lottable06),'') = '' THEN '' ELSE ' AND LA.Lottable06 = @c_Lottable06 ' + CHAR(13) END +  
                      CASE WHEN ISNULL(RTRIM(@c_Lottable07),'') = '' THEN '' ELSE ' AND LA.Lottable07 = @c_Lottable07 ' + CHAR(13) END +  
                      CASE WHEN ISNULL(RTRIM(@c_Lottable08),'') = '' THEN '' ELSE ' AND LA.Lottable08 = @c_Lottable08 ' + CHAR(13) END +  
                      CASE WHEN ISNULL(RTRIM(@c_Lottable09),'') = '' THEN '' ELSE ' AND LA.Lottable09 = @c_Lottable09 ' + CHAR(13) END +  
                      CASE WHEN ISNULL(RTRIM(@c_Lottable10),'') = '' THEN '' ELSE ' AND LA.Lottable10 = @c_Lottable10 ' + CHAR(13) END +  
                      CASE WHEN ISNULL(RTRIM(@c_Lottable11),'') = '' THEN '' ELSE ' AND LA.Lottable11 = @c_Lottable11 ' + CHAR(13) END +  
                      CASE WHEN ISNULL(RTRIM(@c_Lottable12),'') = '' THEN '' ELSE ' AND LA.Lottable12 = @c_Lottable12 ' + CHAR(13) END +  
                      'AND (LOTxLOCxID.QTY - LOTXLOCXID.QtyAllocated - LOTXLOCXID.QtyPicked - LOTXLOCXID.QtyReplen) - ISNULL(##CARLOT.Qty,0)  > 0 
                      AND LOC.LocationType IN(''OTHER'',''DYNPPICK'')
                      AND LOC.LocationCategory IN(''BULK'',''SHELVING'')
                      AND LOC.LocationHandling IN(''1'',''2'')
                      AND LA.Lottable05 = @d_Lottable05
                      GROUP BY LOTxLOCxID.Lot
                      ORDER BY CASE WHEN MIN(LOC.LocationType) = ''DYNPPICK'' THEN 1 ELSE 2 END, CASE WHEN MAX(LOC.LocationHandling) = ''2'' THEN 1 ELSE 2 END '
                      
               SET @c_SQLParm =  N'@c_Facility NVARCHAR(5), @c_StorerKey NVARCHAR(15), @c_SKU NVARCHAR(20), ' +      
                                 '@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18), ' + 
                                 '@c_Lottable06 NVARCHAR(30), @c_Lottable07 NVARCHAR(30), @c_Lottable08 NVARCHAR(30), ' + 
                                 '@c_Lottable09 NVARCHAR(30), @c_Lottable10 NVARCHAR(30), @c_Lottable11 NVARCHAR(30), ' + 
                                 '@c_Lottable12 NVARCHAR(30), @d_Lottable05 DATETIME' 
                        
               EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_Facility, @c_StorerKey, @c_SKU, @c_Lottable01, @c_Lottable02, @c_Lottable03, 
                                  @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10, @c_Lottable11, @c_Lottable12, @d_Lottable05         	
                                  
               OPEN CURSOR_LOT

               FETCH NEXT FROM CURSOR_LOT2 INTO  @c_Lot, @n_LotQty
          
               WHILE (@@FETCH_STATUS <> -1) AND @n_OrderQty > 0 AND @n_QtyAvailable > 0
               BEGIN                
                 	IF @n_LotQty >= @n_QtyAvailable
         	           SET @n_InsertQty = @n_QtyAvailable
         	        ELSE
         	           SET @n_InsertQty = @n_LotQty
               	  
                  IF EXISTS(SELECT 1 FROM ##CARLOT(NOLOCK) WHERE Lot = @c_Lot AND SP_ID = @@SPID)
                  BEGIN
                     UPDATE ##CARLOT WITH (ROWLOCK)
                     SET Qty = Qty + @n_InsertQty
                     WHERE Lot = @c_Lot
                     AND SP_ID = @@SPID
                  END
                  ELSE
                  BEGIN  
                 	   INSERT INTO ##CARLOT (LoT, Qty, QtyAllocated, SP_ID, AddDate)
                 	   VALUES (@c_Lot, @n_InsertQty, 0, @@SPID, GetDate())
                 	END  
                  
                  SET @n_QtyAvailable = @n_QtyAvailable - @n_InsertQty
                  SET @n_OrderQty = @n_OrderQty - @n_InsertQty                              	            	                              	
                 	
                 	/*   
                  UPDATE #LotattributeAllocated
                  SET Qty = Qty - @n_InsertQty
         	        WHERE Storerkey = @c_Storerkey
         	        AND Sku = @c_Sku
         	        AND Facility = @c_Facility
         	        AND Lottable01 = @c_Lottable01
         	        AND Lottable02 = @c_Lottable02
         	        AND Lottable03 = @c_Lottable03
         	        AND Lottable06 = @c_Lottable06
         	        AND Lottable07 = @c_Lottable07
         	        AND Lottable08 = @c_Lottable08
         	        AND Lottable09 = @c_Lottable09
         	        AND Lottable10 = @c_Lottable10
         	        AND Lottable11 = @c_Lottable11
         	        AND Lottable12 = @c_Lottable12
         	        AND Lottable05 = @d_Lottable05

         	        DECLARE CURSOR_ORDGRP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
         	           SELECT SeqNo, OrderQty
         	           FROM #ORDERGROUP
         	           WHERE Storerkey = @c_Storerkey
         	           AND Sku = @c_Sku
         	           AND Facility = @c_Facility
         	           AND Lottable01 = @c_Lottable01
         	           AND Lottable02 = @c_Lottable02
         	           AND Lottable03 = @c_Lottable03
         	           AND Lottable06 = @c_Lottable06
         	           AND Lottable07 = @c_Lottable07
         	           AND Lottable08 = @c_Lottable08
         	           AND Lottable09 = @c_Lottable09
         	           AND Lottable10 = @c_Lottable10
         	           AND Lottable11 = @c_Lottable11
         	           AND Lottable12 = @c_Lottable12
         	           ORDER BY SeqNo
         	        
         	        OPEN CURSOR_ORDGRP
         	        
                  FETCH NEXT FROM CURSOR_ORDGRP INTO @n_SeqNo, @n_Qty
                  
                  WHILE (@@FETCH_STATUS <> -1) AND @n_InsertQty > 0               
                  BEGIN
                  	 IF @n_InsertQty >= @n_Qty
                  	    SET @n_UpdateQty = @n_Qty
                  	 ELSE
                  	    SET @n_UpdateQty = @n_InsertQty
                  
         	           UPDATE #ORDERGROUP
         	           SET OrderQty = OrderQty - @n_UpdateQty
         	           WHERE Storerkey = @c_Storerkey
         	           AND Sku = @c_Sku
         	           AND Facility = @c_Facility
         	           AND Lottable01 = @c_Lottable01
         	           AND Lottable02 = @c_Lottable02
         	           AND Lottable03 = @c_Lottable03
         	           AND Lottable06 = @c_Lottable06
         	           AND Lottable07 = @c_Lottable07
         	           AND Lottable08 = @c_Lottable08
         	           AND Lottable09 = @c_Lottable09
         	           AND Lottable10 = @c_Lottable10
         	           AND Lottable11 = @c_Lottable11
         	           AND Lottable12 = @c_Lottable12
         	           AND SeqNo = @n_SeqNo
                  	  
                  	  SET @n_InsertQty = @n_InsertQty - @n_UpdateQty
                  	    
                     FETCH NEXT FROM CURSOR_ORDGRP INTO @n_SeqNo, @n_Qty
                  END
                  CLOSE CURSOR_ORDGRP
                  DEALLOCATE CURSOR_ORDGRP
                  */
         	                   	                          	
                  FETCH NEXT FROM CURSOR_LOT2 INTO  @c_Lot, @n_LotQty
               END
               CLOSE CURSOR_LOT2
               DEALLOCATE CURSOR_LOT2
                         	                       	  
               FETCH NEXT FROM CURSOR_LOTATTRIBUTEQTY INTO @d_Lottable05, @n_QtyAvailable
            END 
            CLOSE CURSOR_LOTATTRIBUTEQTY
            DEALLOCATE CURSOR_LOTATTRIBUTEQTY      	 
         	
            FETCH NEXT FROM CURSOR_ORDERDET INTO @c_StorerKey, @c_SKU, @c_Facility, @c_Lottable01, @c_Lottable02, @c_Lottable03, @c_Lottable06,
                                                 @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10, @c_Lottable11, @c_Lottable12, @n_OrderQty
         END
         CLOSE CURSOR_ORDERDET
         DEALLOCATE CURSOR_ORDERDET                        	              
      END
      
      DELETE FROM #LOTxLOCxID    
      DELETE FROM #IDxLOC                    
   END 
   --NJOW02 E

   /***************************************************************/
   /***  GET ORDERLINES OF WAVE Group By Ship To & Omnia Order# ***/
   /***************************************************************/
   INSERT INTO #ORDERLINES (ShipTo,
                            OmniaOrderNo,
                            OrderQty,
                            SKU, 
                            PackKey, 
                            StorerKey,
                            Facility,
                            Lottable01,
                            Lottable02,
                            Lottable03,
                            Lottable06,
                            Lottable07,
                            Lottable08,
                            Lottable09,
                            Lottable10,
                            Lottable11,
                            Lottable12)
   SELECT  
      CASE WHEN @c_WaveType = 'E' THEN ''
        ELSE ISNULL(RTRIM(O.M_Address4),'') END,  --NJOW01 
      CASE WHEN @c_WaveType = 'E' THEN ''
        ELSE ISNULL(RTRIM(O.Userdefine03),'') END, --NJOW01
      SUM(OD.OpenQty - (OD.QtyAllocated + OD.QtyPreAllocated + OD.QtyPicked)),
      ISNULL(RTRIM(OD.Sku),''),
      ISNULL(RTRIM(SKU.PackKey),''),
      ISNULL(RTRIM(OD.Storerkey),''),
      ISNULL(RTRIM(O.Facility),''),
      ISNULL(RTRIM(OD.Lottable01),''),
      ISNULL(RTRIM(OD.Lottable02),''),
      ISNULL(RTRIM(OD.Lottable03),''),
      ISNULL(RTRIM(OD.Lottable06),''),
      ISNULL(RTRIM(OD.Lottable07),''),
      ISNULL(RTRIM(OD.Lottable08),''),
      ISNULL(RTRIM(OD.Lottable09),''),
      ISNULL(RTRIM(OD.Lottable10),''),
      ISNULL(RTRIM(OD.Lottable11),''),
      ISNULL(RTRIM(OD.Lottable12),'')
   FROM ORDERDETAIL OD WITH (NOLOCK)  
   JOIN SKU WITH (NOLOCK) ON SKU.StorerKey = OD.StorerKey AND SKU.Sku = OD.Sku  
   JOIN ORDERS O WITH (NOLOCK) ON O.OrderKey = OD.OrderKey  
   JOIN WAVEDETAIL WD WITH (NOLOCK) ON OD.OrderKey = WD.OrderKey
   WHERE WD.Wavekey = @c_WaveKey
     AND O.Type NOT IN ( 'M', 'I' )   
     AND O.SOStatus <> 'CANC'   
     AND O.Status < '9'   
     AND (OD.OpenQty - ( OD.QtyAllocated + OD.QtyPreAllocated + OD.QtyPicked )) > 0
     AND O.OpenQty = CASE WHEN @c_WaveType = 'E' THEN 1 ELSE O.OpenQty END --NJOW01  
   GROUP BY 
      CASE WHEN @c_WaveType = 'E' THEN ''
        ELSE ISNULL(RTRIM(O.M_Address4),'') END,  --NJOW01
      CASE WHEN @c_WaveType = 'E' THEN ''
        ELSE ISNULL(RTRIM(O.Userdefine03),'') END, --NJOW01
      ISNULL(RTRIM(OD.Sku),''),
      ISNULL(RTRIM(SKU.PackKey),''),
      ISNULL(RTRIM(OD.Storerkey),''),
      ISNULL(RTRIM(O.Facility),''),
      ISNULL(RTRIM(OD.Lottable01),''),
      ISNULL(RTRIM(OD.Lottable02),''),
      ISNULL(RTRIM(OD.Lottable03),''),
      ISNULL(RTRIM(OD.Lottable06),''),
      ISNULL(RTRIM(OD.Lottable07),''),
      ISNULL(RTRIM(OD.Lottable08),''),
      ISNULL(RTRIM(OD.Lottable09),''),
      ISNULL(RTRIM(OD.Lottable10),''),
      ISNULL(RTRIM(OD.Lottable11),''),
      ISNULL(RTRIM(OD.Lottable12),'')

   IF @b_Debug = 1
   BEGIN
      SELECT * FROM #ORDERLINES WITH (NOLOCK)
   END

   /*******************************/
   /***  LOOP BY DISTINCT SKU   ***/
   /*******************************/

   DECLARE CURSOR_ORDERLINES CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
   SELECT DISTINCT SKU, StorerKey, Facility, Packkey, Lottable01, Lottable02, Lottable03, Lottable06, 
                   Lottable07, Lottable08, Lottable09, Lottable10, Lottable11, Lottable12
   FROM #ORDERLINES

   OPEN CURSOR_ORDERLINES               
   FETCH NEXT FROM CURSOR_ORDERLINES INTO @c_SKU, @c_StorerKey, @c_Facility, @c_Packkey, @c_Lottable01, @c_Lottable02, @c_Lottable03, @c_Lottable06,
                                          @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10, @c_Lottable11, @c_Lottable12
          
   WHILE (@@FETCH_STATUS <> -1)          
   BEGIN 

      IF @b_Debug = 1
      BEGIN
         PRINT '--------------------------------------------' + CHAR(13) +
               '  @c_SKU: ' +@c_SKU + CHAR(13) + 
               ', @c_StorerKey: ' + @c_StorerKey + CHAR(13) + 
               ', @c_Facility: ' + @c_Facility + CHAR(13) +
               ', @c_Lottable01: ' + @c_Lottable01 + CHAR(13) + 
               ', @c_Lottable02: ' + @c_Lottable02 + CHAR(13) + 
               ', @c_Lottable02: ' + @c_Lottable03 + CHAR(13) + 
               ', @c_Lottable06: ' + @c_Lottable06 + CHAR(13) + 
               ', @c_Lottable07: ' + @c_Lottable07 + CHAR(13) + 
               ', @c_Lottable08: ' + @c_Lottable08 + CHAR(13) + 
               ', @c_Lottable09: ' + @c_Lottable09 + CHAR(13) + 
               ', @c_Lottable10: ' + @c_Lottable10 + CHAR(13) + 
               ', @c_Lottable11: ' + @c_Lottable11 + CHAR(13) + 
               ', @c_Lottable12: ' + @c_Lottable12 +' (' + CONVERT(NVARCHAR(24), GETDATE(), 121) + ')' + CHAR(13) +
               '--------------------------------------------' 
      END

      /************************************************/
      /***  INSERT LOTxLOCxID FOR CURRENT SKU   ***/
      /************************************************/
      -- FIXED: Corrected number of carton (UCC) that can be allocated (UCC.Status does not update until pallet build)
      SET @c_SQL = N'
      INSERT INTO #LOTxLOCxID (Loc, LogicalLocation, Lot, ID, Qty, QtyAvailable, QtyReplen)
      SELECT Loc.Loc, Loc.LogicalLocation, LOTxLOCxID.LOT, LOTxLOCxID.ID, LOTXLOCXID.Qty,
             (LOTXLOCXID.Qty - LOTXLOCXID.QtyAllocated - LOTXLOCXID.QtyPicked - LOTXLOCXID.QtyReplen) AS QtyAvailable,
             LOTXLOCXID.QtyReplen 
      FROM LOTxLOCxID WITH (NOLOCK)      
         JOIN LOC WITH (NOLOCK) ON (LOTxLOCxID.Loc = LOC.LOC)      
         JOIN ID WITH (NOLOCK) ON (LOTxLOCxID.Id = ID.ID AND ID.STATUS <> ''HOLD'')       
         JOIN LOT WITH (NOLOCK) ON (LOTXLOCXID.LOT = LOT.LOT AND LOT.STATUS <> ''HOLD'')         
         JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON LOT.LOT = LA.LOT            
      WHERE LOC.LocationFlag <> ''HOLD''       
         AND LOC.LocationFlag <> ''DAMAGE''       
         AND LOC.Status <> ''HOLD''       
         AND LOC.Facility = @c_Facility   
         AND LOTxLOCxID.STORERKEY = @c_StorerKey
         AND LOTxLOCxID.SKU = @c_SKU ' + CHAR(13) +
         CASE WHEN ISNULL(RTRIM(@c_LocationType),'') = '' THEN '' 
              ELSE ' AND LOC.LocationType = ''' + @c_LocationType + '''' + CHAR(13) END +      
         CASE WHEN ISNULL(RTRIM(@c_LocationCategory),'') = '' THEN ''       
              ELSE ' AND LOC.LocationCategory = ''' + @c_LocationCategory + '''' + CHAR(13) END +      
         CASE WHEN ISNULL(RTRIM(@c_LocationHandling),'') = '' THEN ''       
              ELSE ' AND LOC.LocationHandling = ''' + @c_LocationHandling + '''' + CHAR(13) END +      
         CASE WHEN ISNULL(RTRIM(@c_Lottable01),'') = '' THEN '' ELSE ' AND LA.Lottable01 = @c_Lottable01 ' + CHAR(13) END +      
         CASE WHEN ISNULL(RTRIM(@c_Lottable02),'') = '' THEN '' ELSE ' AND LA.Lottable02 = @c_Lottable02 ' + CHAR(13) END +      
         CASE WHEN ISNULL(RTRIM(@c_Lottable03),'') = '' THEN '' ELSE ' AND LA.Lottable03 = @c_Lottable03 ' + CHAR(13) END +  
         CASE WHEN ISNULL(RTRIM(@c_Lottable06),'') = '' THEN '' ELSE ' AND LA.Lottable06 = @c_Lottable06 ' + CHAR(13) END +  
         CASE WHEN ISNULL(RTRIM(@c_Lottable07),'') = '' THEN '' ELSE ' AND LA.Lottable07 = @c_Lottable07 ' + CHAR(13) END +  
         CASE WHEN ISNULL(RTRIM(@c_Lottable08),'') = '' THEN '' ELSE ' AND LA.Lottable08 = @c_Lottable08 ' + CHAR(13) END +  
         CASE WHEN ISNULL(RTRIM(@c_Lottable09),'') = '' THEN '' ELSE ' AND LA.Lottable09 = @c_Lottable09 ' + CHAR(13) END +  
         CASE WHEN ISNULL(RTRIM(@c_Lottable10),'') = '' THEN '' ELSE ' AND LA.Lottable10 = @c_Lottable10 ' + CHAR(13) END +  
         CASE WHEN ISNULL(RTRIM(@c_Lottable11),'') = '' THEN '' ELSE ' AND LA.Lottable11 = @c_Lottable11 ' + CHAR(13) END +  
         CASE WHEN ISNULL(RTRIM(@c_Lottable12),'') = '' THEN '' ELSE ' AND LA.Lottable12 = @c_Lottable12 ' + CHAR(13) END +  
         'AND (LOTxLOCxID.QTY - LOTXLOCXID.QtyAllocated - LOTXLOCXID.QtyPicked - LOTXLOCXID.QtyReplen) > 0'

      SET @c_SQLParm =  N'@c_Facility   NVARCHAR(5),  @c_StorerKey  NVARCHAR(15), @c_SKU NVARCHAR(20), ' +      
                         '@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18), ' + 
                         '@c_Lottable06 NVARCHAR(30), @c_Lottable07 NVARCHAR(30), @c_Lottable08 NVARCHAR(30), ' + 
                         '@c_Lottable09 NVARCHAR(30), @c_Lottable10 NVARCHAR(30), @c_Lottable11 NVARCHAR(30), ' + 
                         '@c_Lottable12 NVARCHAR(30) ' 
         
      EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_Facility, @c_StorerKey, @c_SKU, @c_Lottable01, @c_Lottable02, @c_Lottable03, 
                         @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10, @c_Lottable11, @c_Lottable12  
      
      --Remove pallet with multi-sku, partial allocated and UCC in progress.
      
      IF ISNULL(@c_WaveType,'') = 'S'  --NJOW02
      BEGIN
         DELETE FROM #LOTxLOCxID      
         WHERE ID IN (
                       SELECT LID.ID
                       FROM #LOTxLOCxID LID
                       JOIN LOTATTRIBUTE LA (NOLOCK) ON LID.LOT = LA.LOT
                       LEFT JOIN UCC WITH (NOLOCK) ON (LID.LOT = UCC.LOT AND LID.LOC = UCC.LOC AND LID.ID = UCC.ID
                                                       AND UCC.Status > '2' AND UCC.Status < '9')
                       WHERE ISNULL(LID.ID,'') <> ''            
                       GROUP BY LID.ID
                       HAVING COUNT(DISTINCT LA.Lottable05) > 1 OR COUNT(DISTINCT LA.SKU) > 1 OR SUM(LID.Qty - LID.QtyAvailable) > 0 OR SUM(CASE WHEN ISNULL(UCC.UCCNo,'') <> '' THEN 1 ELSE 0 END) > 0  --Must be same lottable05
                              OR SUM(LID.QtyReplen) > 0  --NJOW01
                     )      	

         DELETE FROM #IDxLOC
         
         --Retrieve sum qty for the pallet and loc
         INSERT INTO #IDxLOC (ID, LOC, QtyAvailable)
         SELECT LLI.ID, LLI.LOC, SUM(LLI.QtyAvailable)
         FROM #LOTxLOCxID LLI
         JOIN LOTATTRIBUTE LA (NOLOCK) ON LLI.Lot = LA.Lot 
         GROUP BY LLI.ID, LLI.LOC, LLI.LogicalLocation
         ORDER BY MIN(LA.Lottable05), MIN(LLI.Lot), LLI.LogicalLocation, LLI.Loc, LLI.ID  --NJOW02                  
         
         --Delete pallet with non selected lot
         DELETE #IDxLOC
         FROM #IDXLOC
         JOIN #LOTxLOCxID LLI ON #IDXLOC.ID = LLI.ID AND #IDXLOC.Loc = LLI.Loc
         LEFT JOIN ##CARLOT (NOLOCK) ON LLI.Lot = ##CARLOT.Lot AND ##CARLOT.Qty - ##CARLOT.QtyAllocated > 0 AND ##CARLOT.SP_ID = @@SPID 
         WHERE ##CARLOT.Lot IS NULL          
      END
      ELSE
      BEGIN
         DELETE FROM #LOTxLOCxID      
         WHERE ID IN (
                       SELECT LID.ID
                       FROM #LOTxLOCxID LID
                       JOIN LOTATTRIBUTE LA (NOLOCK) ON LID.LOT = LA.LOT
                       LEFT JOIN UCC WITH (NOLOCK) ON (LID.LOT = UCC.LOT AND LID.LOC = UCC.LOC AND LID.ID = UCC.ID
                                                       AND UCC.Status > '2' AND UCC.Status < '9')
                       WHERE ISNULL(LID.ID,'') <> ''            
                       GROUP BY LID.ID
                       HAVING COUNT(DISTINCT LA.SKU) > 1 OR SUM(LID.Qty - LID.QtyAvailable) > 0 OR SUM(CASE WHEN ISNULL(UCC.UCCNo,'') <> '' THEN 1 ELSE 0 END) > 0 
                              OR SUM(LID.QtyReplen) > 0  --NJOW01
                       --HAVING COUNT(DISTINCT LA.Lot) > 1 OR SUM(LID.Qty - LID.QtyAvailable) > 0 OR SUM(CASE WHEN ISNULL(UCC.UCCNo,'') <> '' THEN 1 ELSE 0 END) > 0 
                       --       OR SUM(LID.QtyReplen) > 0  --NJOW01
                     )

         DELETE FROM #IDxLOC
         
         --Retrieve sum qty for the pallet and loc
         INSERT INTO #IDxLOC (ID, LOC, QtyAvailable)
         SELECT LLI.ID, LLI.LOC, SUM(LLI.QtyAvailable)
         FROM #LOTxLOCxID LLI
         JOIN LOTATTRIBUTE LA (NOLOCK) ON LLI.Lot = LA.Lot 
         GROUP BY LLI.ID, LLI.LOC, LLI.LogicalLocation
         ORDER BY MIN(LA.Lottable05), MIN(LLI.Lot), LLI.LogicalLocation, LLI.Loc, LLI.ID  --NJOW02
      END            
      
                  
      --Get Lower Bound to reduce loop size
      SELECT @n_LowerBound = MIN(QtyAvailable)      
      FROM #IDxLOC

      /*****************************************************************************/
      /***  START ALLOC BY ORDER GROUP (ShipTo & Omnia Order No)                 ***/
      /*****************************************************************************/
      SET @c_SQL = N'
      DECLARE CURSOR_ORDERLINE_SKU CURSOR FAST_FORWARD READ_ONLY FOR 
      SELECT ShipTo, OmniaOrderNo, OrderQty
      FROM #ORDERLINES WITH (NOLOCK)
      WHERE OrderQty >= @n_LowerBound 
        AND SKU = @c_SKU 
        AND StorerKey = @c_StorerKey
        AND Facility = @c_Facility ' + CHAR(13) + 
        CASE WHEN ISNULL(RTRIM(@c_Lottable01),'') = '' THEN '' ELSE ' AND Lottable01 = @c_Lottable01 ' + CHAR(13) END +      
        CASE WHEN ISNULL(RTRIM(@c_Lottable02),'') = '' THEN '' ELSE ' AND Lottable02 = @c_Lottable02 ' + CHAR(13) END +      
        CASE WHEN ISNULL(RTRIM(@c_Lottable03),'') = '' THEN '' ELSE ' AND Lottable03 = @c_Lottable03 ' + CHAR(13) END +      
        CASE WHEN ISNULL(RTRIM(@c_Lottable06),'') = '' THEN '' ELSE ' AND Lottable06 = @c_Lottable06 ' + CHAR(13) END +      
        CASE WHEN ISNULL(RTRIM(@c_Lottable07),'') = '' THEN '' ELSE ' AND Lottable07 = @c_Lottable07 ' + CHAR(13) END +      
        CASE WHEN ISNULL(RTRIM(@c_Lottable08),'') = '' THEN '' ELSE ' AND Lottable08 = @c_Lottable08 ' + CHAR(13) END +      
        CASE WHEN ISNULL(RTRIM(@c_Lottable09),'') = '' THEN '' ELSE ' AND Lottable09 = @c_Lottable09 ' + CHAR(13) END +      
        CASE WHEN ISNULL(RTRIM(@c_Lottable10),'') = '' THEN '' ELSE ' AND Lottable10 = @c_Lottable10 ' + CHAR(13) END +      
        CASE WHEN ISNULL(RTRIM(@c_Lottable11),'') = '' THEN '' ELSE ' AND Lottable11 = @c_Lottable11 ' + CHAR(13) END +      
        CASE WHEN ISNULL(RTRIM(@c_Lottable12),'') = '' THEN '' ELSE ' AND Lottable12 = @c_Lottable12 ' END
 
      SET @c_SQLParm =  N'@n_LowerBound INT, @c_SKU NVARCHAR(20), @c_StorerKey NVARCHAR(15), @c_Facility NVARCHAR(5), ' +      
                         '@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18), '  +
                         '@c_Lottable06 NVARCHAR(30), @c_Lottable07 NVARCHAR(30), @c_Lottable08 NVARCHAR(30), '  +
                         '@c_Lottable09 NVARCHAR(30), @c_Lottable10 NVARCHAR(30), @c_Lottable11 NVARCHAR(30), @c_Lottable12 NVARCHAR(30) ' 
         
      EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @n_LowerBound, @c_SKU, @c_StorerKey, @c_Facility, @c_Lottable01, @c_Lottable02, @c_Lottable03,
                         @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10, @c_Lottable11, @c_Lottable12

      OPEN CURSOR_ORDERLINE_SKU               
      FETCH NEXT FROM CURSOR_ORDERLINE_SKU INTO @c_ShipTo, @c_OmniaOrderNo, @n_OrderQty
      
      --Retrieve all the order groups of the sku      
      WHILE (@@FETCH_STATUS <> -1) 
      BEGIN    
         IF @b_Debug = 1
         BEGIN
            SELECT @c_ShipTo AS 'ShipTo', @c_OmniaOrderNo AS 'OmniaOrderNo', @n_OrderQty AS 'OrderQty'
            PRINT 'ShipTo: ' + @c_ShipTo + ', OmniaOrderNo: ' + @c_OmniaOrderNo + ', OrderQty: ' + CAST(@n_OrderQty AS NVARCHAR) 
            PRINT 'STEP 1: START - ' + CONVERT(NVARCHAR(24), GETDATE(), 121)
         END         
         
         --Allocate the order group
         WHILE @n_OrderQty > 0
         BEGIN         
            SELECT @c_ID = '', @c_Loc ='',  @n_IDQty = 0, @n_PickQty = 0
            
            --Find the full pallet
            IF ISNULL(@c_WaveType,'') = 'S'  --NJOW02
            BEGIN
            	 --make sure the lot in pallet are enough with reserved lot qty
               SELECT TOP 1 @c_ID = ID, @c_Loc = Loc, @n_IDQty = QtyAvailable
               FROM #IDxLOC            
               WHERE QtyAvailable <= @n_OrderQty
               AND QtyAvailable > 0
               AND NOT EXISTS (SELECT 1 
                               FROM #LOTxLOCxID LLI 
                               LEFT JOIN ##CARLOT (NOLOCK) ON LLI.Lot = ##CARLOT.Lot AND ##CARLOT.SP_ID = @@SPID                    
                               WHERE LLI.ID = #IDxLOC.ID 
                               AND LLI.Loc = #IDxLOC.Loc
                               GROUP BY LLI.Lot, ##CARLOT.Qty, ##CARLOT.QtyAllocated
                               HAVING SUM(LLI.QtyAvailable) > (ISNULL(##CARLOT.Qty,0) - ISNULL(##CARLOT.QtyAllocated,0)))
               ORDER BY SeqNo
            END
            ELSE
            BEGIN
               SELECT TOP 1 @c_ID = ID, @c_Loc = Loc, @n_IDQty = QtyAvailable
               FROM #IDxLOC
               WHERE QtyAvailable <= @n_OrderQty
               AND QtyAvailable > 0
               ORDER BY SeqNo
            END
            
            IF ISNULL(@n_IDQty,0) = 0
               BREAK
            
            DECLARE CURSOR_PICKID CURSOR FAST_FORWARD READ_ONLY FOR 
            SELECT Lot, QtyAvailable
            FROM #LOTxLOCxID WITH (NOLOCK)
            WHERE ID = @c_ID
            AND LOC = @c_Loc

            OPEN CURSOR_PICKID               
            FETCH NEXT FROM CURSOR_PICKID INTO @c_Lot, @n_PickQty
                   
            --Retrieve all lots of the pallet
            WHILE (@@FETCH_STATUS <> -1)          
            BEGIN 
               SET @c_SQL = N'
               DECLARE CURSOR_ORDLINE CURSOR FAST_FORWARD READ_ONLY FOR 
               SELECT O.Orderkey, OD.OrderLineNumber, OD.OpenQty - ( OD.QtyAllocated + OD.QtyPreAllocated + OD.QtyPicked ) AS Qty
               FROM ORDERS O (NOLOCK)
               JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey
               JOIN WAVEDETAIL WD (NOLOCK) ON WD.Orderkey = O.Orderkey
               WHERE OD.SKU = @c_SKU 
               AND O.StorerKey = @c_StorerKey
               AND WD.Wavekey = @c_Wavekey
               AND OD.OpenQty - ( OD.QtyAllocated + OD.QtyPreAllocated + OD.QtyPicked ) > 0 ' +
               CASE WHEN @c_WaveType = 'E' THEN '' ELSE ' AND O.M_Address4 = @c_ShipTo ' END +   --NJOW01
               CASE WHEN @c_WaveType = 'E' THEN '' ELSE ' AND O.Userdefine03 = @c_OmniaOrderNo ' END +  --NJOW01
               ' AND O.Facility = @c_Facility ' + CHAR(13) + 
               CASE WHEN ISNULL(RTRIM(@c_Lottable01),'') = '' THEN '' ELSE ' AND OD.Lottable01 = @c_Lottable01 ' + CHAR(13) END +      
               CASE WHEN ISNULL(RTRIM(@c_Lottable02),'') = '' THEN '' ELSE ' AND OD.Lottable02 = @c_Lottable02 ' + CHAR(13) END +      
               CASE WHEN ISNULL(RTRIM(@c_Lottable06),'') = '' THEN '' ELSE ' AND OD.Lottable06 = @c_Lottable06 ' + CHAR(13) END +      
               CASE WHEN ISNULL(RTRIM(@c_Lottable07),'') = '' THEN '' ELSE ' AND OD.Lottable07 = @c_Lottable07 ' + CHAR(13) END +      
               CASE WHEN ISNULL(RTRIM(@c_Lottable08),'') = '' THEN '' ELSE ' AND OD.Lottable08 = @c_Lottable08 ' + CHAR(13) END +      
               CASE WHEN ISNULL(RTRIM(@c_Lottable09),'') = '' THEN '' ELSE ' AND OD.Lottable09 = @c_Lottable09 ' + CHAR(13) END +      
               CASE WHEN ISNULL(RTRIM(@c_Lottable10),'') = '' THEN '' ELSE ' AND OD.Lottable10 = @c_Lottable10 ' + CHAR(13) END +      
               CASE WHEN ISNULL(RTRIM(@c_Lottable11),'') = '' THEN '' ELSE ' AND OD.Lottable11 = @c_Lottable11 ' + CHAR(13) END +      
               CASE WHEN ISNULL(RTRIM(@c_Lottable12),'') = '' THEN '' ELSE ' AND OD.Lottable12 = @c_Lottable12 ' END +
               'ORDER BY O.Orderkey'
               
               SET @c_SQLParm =  N'@c_Shipto NVARCHAR(45), @c_OmniaOrderno NVARCHAR(20), @c_SKU NVARCHAR(20), @c_StorerKey NVARCHAR(15), @c_Wavekey NVARCHAR(10), @c_Facility NVARCHAR(5), ' +      
                                  '@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18), ' +
                                  '@c_Lottable06 NVARCHAR(30), @c_Lottable07 NVARCHAR(30), @c_Lottable08 NVARCHAR(30), ' +
                                  '@c_Lottable09 NVARCHAR(30), @c_Lottable10 NVARCHAR(30), @c_Lottable11 NVARCHAR(30), ' +
                                  '@c_Lottable12 NVARCHAR(30) ' 
                  
               EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_ShipTo, @c_OmniaOrderNo, @c_SKU, @c_StorerKey, @c_Wavekey, @c_Facility, @c_Lottable01, @c_Lottable02, 
                                  @c_Lottable03, @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10, @c_Lottable11, @c_Lottable12
                        
               OPEN CURSOR_ORDLINE               
               FETCH NEXT FROM CURSOR_ORDLINE INTO @c_Orderkey, @c_OrderLineNumber, @n_OrderLineQty
               
               --Retrieve all order lines for the order group and create pickdetail
               WHILE (@@FETCH_STATUS <> -1) AND @n_PickQty > 0         
               BEGIN 
               	 IF @n_OrderLineQty <= @n_PickQty 
               	 BEGIN
               	    SET @n_InsertQty = @n_OrderLineQty
               	    SET @n_PickQty = @n_PickQty - @n_OrderLineQty
               	 END
               	 ELSE
               	 BEGIN
               	 	  SET @n_InsertQty = @n_PickQty
               	 	  SET @n_PickQty = 0
               	 END
               	    
                  -- INSERT #PickDetail
                  EXECUTE nspg_getkey  
                    'PickDetailKey'  
                    , 10  
                    , @c_PickDetailKey OUTPUT  
                    , @b_Success       OUTPUT  
                    , @n_Err           OUTPUT  
                    , @c_ErrMsg        OUTPUT  
                  
                  IF @b_Success <> 1  
                  BEGIN
                     SET @n_Continue = 3
                     SET @n_Err = 13000
                     SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) + 
                                     ': Get PickDetailKey Failed. (ispPRCAR01)'
                     GOTO Quit
                  END
                  ELSE
                  BEGIN
                     IF @b_Debug = 1
                     BEGIN
                        PRINT 'PickDetailKey: ' + @c_PickDetailKey + CHAR(13) +
                              'OrderKey: ' + @c_OrderKey + CHAR(13) +
                              'OrderLineNumber: ' + @c_OrderLineNumber + CHAR(13) +
                              'PickQty: ' + CAST(@n_PickQty AS NVARCHAR) + CHAR(13) +
                              'InsertQty: ' + CAST(@n_InsertQty AS NVARCHAR) + CHAR(13) +
                              'SKU: ' + @c_SKU + CHAR(13) +
                              'PackKey: ' + @c_PackKey + CHAR(13) +
                              'Lot: ' + @c_Lot + CHAR(13) +
                              'Loc: ' + @c_Loc + CHAR(13) +
                              'ID: ' + @c_ID + CHAR(13) +
                              'UOM: ' + @c_UOM + CHAR(13)
                     END
                                          
                     INSERT PICKDETAIL (  
                         PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber,  
                         Lot, StorerKey, Sku, UOM, UOMQty, Qty, 
                         Loc, Id, PackKey, CartonGroup, DoReplenish,  
                         replenishzone, doCartonize, Trafficcop, PickMethod  
                     ) VALUES (  
                         @c_PickDetailKey, '', '', @c_OrderKey, @c_OrderLineNumber,  
                         @c_Lot, @c_StorerKey, @c_SKU, @c_UOM, @n_InsertQty, @n_InsertQty, 
                         @c_Loc, @c_ID, @c_PackKey, '', 'N',  
                         '', NULL, 'U', @c_PickMethod  
                     ) 
                  
                     IF @@ERROR <> 0
                     BEGIN
                        SET @n_Continue = 3
                        SET @n_Err = 13001
                        SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) + 
                                        ': Insert PickDetail Failed. (ispPRCAR01)'
                        GOTO Quit
                     END
                  END -- IF @b_Success = 1                  	 
               	 
                  FETCH NEXT FROM CURSOR_ORDLINE INTO @c_Orderkey, @c_OrderLineNumber, @n_OrderLineQty
               END
               CLOSE CURSOR_ORDLINE         
               DEALLOCATE CURSOR_ORDLINE    
               
               --NJOW02
               IF ISNULL(@c_WaveType,'') = 'S' 
               BEGIN 
                  UPDATE ##CARLOT WITH (ROWLOCK)
                  SET QtyAllocated = QtyAllocated + @n_Pickqty
                  WHERE Lot = @c_Lot  
                  AND SP_ID = @@SPID
               END
                               	
               FETCH NEXT FROM CURSOR_PICKID INTO @c_Lot, @n_PickQty
            END
            CLOSE CURSOR_PICKID         
            DEALLOCATE CURSOR_PICKID
            
            SET @n_OrderQty = @n_OrderQty - @n_IDQty
            
            DELETE FROM #LOTxLOCxID WHERE ID = @c_ID AND LOC = @c_Loc
            DELETE FROM #IDxLOC WHERE ID = @c_ID AND LOC = @c_Loc
         END

         FETCH NEXT FROM CURSOR_ORDERLINE_SKU INTO @c_ShipTo, @c_OmniaOrderNo, @n_OrderQty
      END -- END WHILE FOR CURSOR_ORDERLINE_SKU              
      CLOSE CURSOR_ORDERLINE_SKU
      DEALLOCATE CURSOR_ORDERLINE_SKU

      
      /*****************************/
      /***  Clear All TEMP Table ***/
      /*****************************/
      DELETE FROM #LOTxLOCxID
      DELETE FROM #IDXLOC

      IF @b_Debug = 1
      BEGIN
         PRINT '--------------------------------------------' + CHAR(13)
      END

      FETCH NEXT FROM CURSOR_ORDERLINES INTO @c_SKU, @c_StorerKey, @c_Facility, @c_Packkey, @c_Lottable01, @c_Lottable02, @c_Lottable03, @c_Lottable06,
                                             @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10, @c_Lottable11, @c_Lottable12
   END -- END WHILE FOR CURSOR_ORDERLINES             
   CLOSE CURSOR_ORDERLINES          
   DEALLOCATE CURSOR_ORDERLINES

   IF @b_Debug = 1
   BEGIN
      SELECT PD.PickDetailKey, PD.OrderKey, PD.OrderLineNumber, PD.Qty, PD.SKU, PD.PackKey, PD.Lot, PD.Loc, PD.ID, PD.UOM
      FROM PickDetail PD WITH (NOLOCK)
      JOIN OrderDetail OD WITH (NOLOCK) ON (OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber)
      JOIN WAVEDETAIL WD WITH (NOLOCK) ON (OD.OrderKey = WD.OrderKey)
      WHERE WD.Wavekey = @c_Wavekey
   END

QUIT:

   IF (SELECT CURSOR_STATUS('LOCAL','CURSOR_ORDERLINES')) >=0 
   BEGIN
      CLOSE CURSOR_ORDERLINES           
      DEALLOCATE CURSOR_ORDERLINES      
   END  

   IF (SELECT CURSOR_STATUS('LOCAL','CURSOR_ORDERLINE_SKU')) >=0 
   BEGIN
      CLOSE CURSOR_ORDERLINE_SKU           
      DEALLOCATE CURSOR_ORDERLINE_SKU      
   END  

   IF (SELECT CURSOR_STATUS('LOCAL','CURSOR_PICKID')) >=0 
   BEGIN
      CLOSE CURSOR_PICKUCC           
      DEALLOCATE CURSOR_PICKUCC      
   END  

   IF (SELECT CURSOR_STATUS('LOCAL','CURSOR_ORDLINE')) >=0 
   BEGIN
      CLOSE CURSOR_ORDLINE           
      DEALLOCATE CURSOR_ORDLINE      
   END  
      
   IF OBJECT_ID('tempdb..#ORDERLINES','u') IS NOT NULL
      DROP TABLE #ORDERLINES;

   IF OBJECT_ID('tempdb..#LOTxLOCxID','u') IS NOT NULL
      DROP TABLE #LOTxLOCxID;

   IF OBJECT_ID('tempdb..#IDxLOC','u') IS NOT NULL
      DROP TABLE #IDxLOC;

   --NJOW02 S
   IF (SELECT CURSOR_STATUS('GLOBAL','CURSOR_LOT1')) >=0 
   BEGIN
      CLOSE CURSOR_LOT1           
      DEALLOCATE CURSOR_LOT1      
   END  

   IF (SELECT CURSOR_STATUS('GLOBAL','CURSOR_LOT2')) >=0 
   BEGIN
      CLOSE CURSOR_LOT2           
      DEALLOCATE CURSOR_LOT2      
   END  

   IF OBJECT_ID('tempdb..#ORDERGROUP','u') IS NOT NULL
      DROP TABLE #ORDERGROUP

   IF OBJECT_ID('tempdb..#LotAttributeAllocated','u') IS NOT NULL
      DROP TABLE #LotAttributeAllocated
      
   IF OBJECT_ID('tempdb..#IDxLOC_USED','u') IS NOT NULL
      DROP TABLE #IDxLOC_USED

   IF OBJECT_ID('tempdb..#UCC_USED','u') IS NOT NULL
      DROP TABLE #UCC_USED
   --NJOW02 E
      
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
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispPRCAR01'  
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

END -- Procedure

GO