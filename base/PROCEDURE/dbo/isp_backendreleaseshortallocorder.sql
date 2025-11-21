SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_BackendReleaseShortAllocOrder                  */
/* Creation Date:                                                       */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.3 (Unicode)                                          */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Rev   Purposes                                  */
/* 27-JUL-2018  Shong   1.1   Delete Short Alloc Order                  */
/*                            AutoAllocBatchDEtail in order to re-process*/ 
/*                            when there is availble inventory          */ 
/* 17-Jun-2019  Shong   1.2   Release by Lottable Match with Ord Det    */
/* 20-Jun-2019  NJOW01  1.3   WMS-9408 not to re-submit                 */ 
/*                            if orders.updatesource = '1'              */
/* 09-OCT-2023  NJOW02  1.4   WMS-23852 Allow skip lottable filtering   */
/* 09-OCT-2023  NJOW02  1.4   DEVOPS Combine Script                     */
/************************************************************************/
CREATE   PROC [dbo].[isp_BackendReleaseShortAllocOrder] (
     @bSuccess      INT = 1            OUTPUT
   , @nErr          INT = ''           OUTPUT
   , @cErrMsg       NVARCHAR(250) = '' OUTPUT	
	 , @bDebug        INT = 0 ) 
AS 
BEGIN
   DECLARE @n_AllocBatchNo    BIGINT = 0, 
           @c_OrderKey        NVARCHAR(10) = '', 
           @n_RowRef          BIGINT = 0, 
           @n_TotalSKU        INT = 0 ,
           @n_AllowDelete     INT = 1, 
           @c_LottableFilter  NVARCHAR(2000) = '',
           @c_SQL             NVARCHAR(4000) = '', 
           @c_SQLParm         NVARCHAR(4000) = '',
	         @c_StorerKey       NVARCHAR(15)   = '', 
	         @c_SKU             NVARCHAR(20)   = '', 
           @c_Lottable01      NVARCHAR(18)   = '',
           @c_Lottable02      NVARCHAR(18)   = '',
           @c_Lottable03      NVARCHAR(18)   = '',	
           @c_Lottable06      NVARCHAR(30)   = '',
           @c_Lottable07      NVARCHAR(30)   = '',
           @c_Lottable08      NVARCHAR(30)   = '',
           @c_Lottable09      NVARCHAR(30)   = '',
           @c_Lottable10      NVARCHAR(30)   = '',
           @c_Lottable11      NVARCHAR(30)   = '',
           @c_Lottable12      NVARCHAR(30)   = '', 
           @n_QtyAvailable    INT = 0, 	
           @c_Facility	      NVARCHAR(5)    = '',  --NJOW02
           @c_SkipLotChk      NVARCHAR(30)   = ''   --NJOW02              

   DECLARE CUR_ReAllocate_Order CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT aabd.AllocBatchNo, o.OrderKey, aabd.TotalSKU 
   FROM AutoAllocBatchDetail AS aabd WITH(NOLOCK) 
   JOIN ORDERDETAIL AS o WITH(NOLOCK) ON o.OrderKey = aabd.OrderKey 
   JOIN ORDERS AS OH WITH (NOLOCK) ON OH.OrderKey = o.OrderKey 
   WHERE OH.[Status] IN ('0', '1')
   AND aabd.[Status] IN ('6','9','8')  
   AND EXISTS(SELECT 1 
              FROM SKUxLOC SL WITH (NOLOCK) 
              JOIN LOC L WITH (NOLOCK) ON L.LOC = SL.LOC  
              WHERE SL.StorerKey = o.StorerKey 
              AND SL.Sku = o.Sku 
              AND L.LocationFlag NOT IN ('HOLD','DAMAGE')
              AND L.[Status] <> 'HOLD'              
              AND L.Facility = OH.Facility
              GROUP BY SL.StorerKey, SL.Sku 
              HAVING SUM(SL.Qty - (SL.QtyAllocated + SL.QtyPicked)) > 0 )
   AND NOT EXISTS (SELECT 1 FROM CODELKUP (NOLOCK)
                   WHERE Listname = 'AUTOALLOC'
                   AND Storerkey = OH.Storerkey
                   AND Notes = OH.Facility
                   AND UDF01 = '1'
                   AND OH.UpdateSource = '1')  --NJOW01

   OPEN CUR_ReAllocate_Order

   FETCH NEXT FROM CUR_ReAllocate_Order INTO @n_AllocBatchNo, @c_OrderKey, @n_TotalSKU
   WHILE @@FETCH_STATUS=0
   BEGIN
	   SET @n_RowRef = 0 
	   SET @n_AllowDelete = 1

	   IF @n_TotalSKU > 1 
	   BEGIN
	      IF EXISTS (SELECT 1 FROM AutoAllocBatchJob AS aabj WITH(NOLOCK) 
	                 WHERE aabj.AllocBatchNo = @n_AllocBatchNo 
	                 AND aabj.[Status] IN ('0','1')
	                 AND SKU IN (SELECT DISTINCT SKU FROM ORDERDETAIL AS o WITH(NOLOCK)
	                             WHERE o.OrderKey = @c_OrderKey ) )
	      BEGIN
	      	SET @n_AllowDelete = 0 
	      	GOTO FETCH_NEXT 
	      END	   	
	   END	   
	   
	   --NJOW02 S	  	   
	   SELECT @c_Storerkey = Storerkey, 
	          @c_Facility = Facility
	   FROM ORDERS (NOLOCK)
	   WHERE Orderkey = @c_Orderkey
	   
	   SET @c_SkipLotChk = ''
	   SELECT @c_SkipLotChk = SC.Authority
     FROM dbo.fnc_GetRight2(@c_Facility, @c_Storerkey,'','AutoAllocRelShortSkipLotChk') AS SC
     
     IF @c_SkipLotChk = '1'
     BEGIN
        SET @c_SkipLotChk = '01,02,03,06,07,08,09,10,11,12'
     END
     --NJOW02 E
	   	   
	   DECLARE CUR_ORDERDET_LOTTABLE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
	   SELECT Sku, 
	          StorerKey, 
	          ISNULL(Lottable01,''), 
	          ISNULL(Lottable02,''), 
	          ISNULL(Lottable03,''), 
	          ISNULL(Lottable06,''),
	          ISNULL(Lottable07,''), 
	          ISNULL(Lottable08,''), 
	          ISNULL(Lottable09,''), 
	          ISNULL(Lottable10,''), 
	          ISNULL(Lottable11,''),
	          ISNULL(Lottable12,'')
	   FROM ORDERDETAIL WITH (NOLOCK)
	   WHERE OrderKey = @c_OrderKey 
	   AND   [Status] IN ('0','1') 
	   
	   OPEN CUR_ORDERDET_LOTTABLE
	   
	   FETCH FROM CUR_ORDERDET_LOTTABLE INTO @c_Sku, @c_StorerKey, @c_Lottable01,
	                             @c_Lottable02, @c_Lottable03, @c_Lottable06,
	                             @c_Lottable07, @c_Lottable08, @c_Lottable09,
	                             @c_Lottable10, @c_Lottable11, @c_Lottable12
	   
	   WHILE @@FETCH_STATUS = 0
	   BEGIN
	   	SET @c_LottableFilter = N''
	   	
	   	IF ISNULL(RTRIM(@c_Lottable01),'') <> '' AND CHARINDEX('01',@c_SkipLotChk,1) = 0  --NJOW01
	   	BEGIN
	   		SET @c_LottableFilter = @c_LottableFilter + ' AND Lottable01 = @c_Lottable01 '
	   	END
	   	IF ISNULL(RTRIM(@c_Lottable02),'') <> '' AND CHARINDEX('02',@c_SkipLotChk,1) = 0  
	   	BEGIN
	   		SET @c_LottableFilter = @c_LottableFilter + ' AND Lottable02 = @c_Lottable02 '
	   	END
	   	IF ISNULL(RTRIM(@c_Lottable03),'') <> '' AND CHARINDEX('03',@c_SkipLotChk,1) = 0  
	   	BEGIN
	   		SET @c_LottableFilter = @c_LottableFilter + ' AND Lottable03 = @c_Lottable03 '
	   	END
	   	IF ISNULL(RTRIM(@c_Lottable06),'') <> '' AND CHARINDEX('06',@c_SkipLotChk,1) = 0  
	   	BEGIN
	   		SET @c_LottableFilter = @c_LottableFilter + ' AND Lottable06 = @c_Lottable06 '
	   	END
	   	IF ISNULL(RTRIM(@c_Lottable07),'') <> '' AND CHARINDEX('07',@c_SkipLotChk,1) = 0  
	   	BEGIN
	   		SET @c_LottableFilter = @c_LottableFilter + ' AND Lottable07 = @c_Lottable07 '
	   	END
	   	IF ISNULL(RTRIM(@c_Lottable08),'') <> '' AND CHARINDEX('08',@c_SkipLotChk,1) = 0
	   	BEGIN
	   		SET @c_LottableFilter = @c_LottableFilter + ' AND Lottable08 = @c_Lottable08 '
	   	END
	   	IF ISNULL(RTRIM(@c_Lottable09),'') <> '' AND CHARINDEX('09',@c_SkipLotChk,1) = 0
	   	BEGIN
	   		SET @c_LottableFilter = @c_LottableFilter + ' AND Lottable09 = @c_Lottable09 '
	   	END	   		   		   		   		   		   	
	   	IF ISNULL(RTRIM(@c_Lottable10),'') <> '' AND CHARINDEX('10',@c_SkipLotChk,1) = 0
	   	BEGIN
	   		SET @c_LottableFilter = @c_LottableFilter + ' AND Lottable10 = @c_Lottable10 '
	   	END	
	   	IF ISNULL(RTRIM(@c_Lottable11),'') <> '' AND CHARINDEX('11',@c_SkipLotChk,1) = 0
	   	BEGIN
	   		SET @c_LottableFilter = @c_LottableFilter + ' AND Lottable11 = @c_Lottable11 '
	   	END	   
	   	IF ISNULL(RTRIM(@c_Lottable12),'') <> '' AND CHARINDEX('12',@c_SkipLotChk,1) = 0
	   	BEGIN
	   		SET @c_LottableFilter = @c_LottableFilter + ' AND Lottable12 = @c_Lottable12 '
	   	END	   	   		   	   
	   	
	   	SET @c_SQL = N'SET @n_QtyAvailable = 0 ; ' + 
	   	             N'SELECT @n_QtyAvailable = L.Qty - L.QtyAllocated - L.QtyPicked - L.QtyOnHold ' + 
	   	             N'FROM LOT AS L WITH(NOLOCK) ' + 
	   	             N'JOIN LOTATTRIBUTE AS LA WITH(NOLOCK) ON LA.Lot = l.Lot ' +
	   	             N'WHERE L.StorerKey = @c_StorerKey ' +
	   	             N'AND L.Sku = @c_SKU ' + 
	   	             @c_LottableFilter + 
	   	             N'AND L.Qty - L.QtyAllocated - L.QtyPicked - L.QtyOnHold > 0 ' 
	   	             
	   	SET @c_SQLParm = N'@c_Sku nvarchar(20), @c_StorerKey nvarchar(15), ' + 
              N'@c_Lottable01 nvarchar(18), @c_Lottable02 nvarchar(18), ' + 
              N'@c_Lottable03 nvarchar(18), @c_Lottable06 nvarchar(30), ' + 
              N'@c_Lottable07 nvarchar(30), @c_Lottable08 nvarchar(30), ' + 
              N'@c_Lottable09 nvarchar(30), @c_Lottable10 nvarchar(30), ' + 
              N'@c_Lottable11 nvarchar(30), @c_Lottable12 nvarchar(30), ' + 
              N'@n_QtyAvailable INT OUTPUT' 
	   	
	   	IF @bDebug = 1
	   	BEGIN
	   		PRINT @c_SQL
	   	END
	   	
	   	EXEC sp_ExecuteSql @c_SQL, @c_SQLParm, 
	   		  @c_Sku, @c_StorerKey, @c_Lottable01,
	   	     @c_Lottable02, @c_Lottable03,
	   	     @c_Lottable06, @c_Lottable07,
	   	     @c_Lottable08, @c_Lottable09,
	   	     @c_Lottable10, @c_Lottable11, @c_Lottable12, 
	   	     @n_QtyAvailable OUTPUT 

         IF @n_QtyAvailable > 0 
         BEGIN
	         SELECT @n_RowRef = aabd.RowRef
	         FROM AutoAllocBatchDetail AS aabd WITH(NOLOCK)
	         WHERE aabd.AllocBatchNo = @n_AllocBatchNo 
	         AND aabd.OrderKey = @c_OrderKey
	         IF @n_RowRef > 0 
	         BEGIN
	         	IF @bDebug = 1
	         	BEGIN
	         	   PRINT 'Release Order# ' + @c_OrderKey
	         	   PRINT 'SKU : ' + @c_SKU	
	         	END
	         		         	
		         DELETE AutoAllocBatchDetail
		         WHERE RowRef = @n_RowRef
		         
		         BREAK 
	         END         	
         END	   	     
         
	   	FETCH FROM CUR_ORDERDET_LOTTABLE INTO @c_Sku, @c_StorerKey, @c_Lottable01,
	   	                          @c_Lottable02, @c_Lottable03,
	   	                          @c_Lottable06, @c_Lottable07,
	   	                          @c_Lottable08, @c_Lottable09,
	   	                          @c_Lottable10, @c_Lottable11, @c_Lottable12
	   END	   
	   CLOSE CUR_ORDERDET_LOTTABLE
	   DEALLOCATE CUR_ORDERDET_LOTTABLE	   

      FETCH_NEXT:
         	   
	   FETCH NEXT FROM CUR_ReAllocate_Order INTO @n_AllocBatchNo, @c_OrderKey, @n_TotalSKU
   END
   CLOSE CUR_ReAllocate_Order
   DEALLOCATE CUR_ReAllocate_Order
	
END -- Procedure

GO