SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: ispPRALC04                                         */  
/* Creation Date: 18-Jan-2021                                           */  
/* Copyright: LFL                                                       */  
/* Written by: WLChooi                                                  */  
/*                                                                      */  
/* Purpose:  WMS-16049 - CN_Volmont_Exceed_Split Order Line before      */
/*                       Allocation                                     */  
/*           Set the sp to storerconfig PreAllocationSP                 */
/*                                                                      */  
/* Called By: ispPreAllocationWrapper                                   */  
/*                                                                      */  
/* GitLab Version: 1.0                                                  */  
/*                                                                      */  
/* Version: 1.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author  Rev   Purposes                                  */  
/************************************************************************/  
CREATE PROC [dbo].[ispPRALC04] (
     @c_OrderKey        NVARCHAR(10)  
   , @c_LoadKey         NVARCHAR(10)    
   , @c_WaveKey         NVARCHAR(10)  
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
          ,@c_Short                  NVARCHAR(50)
          ,@c_UDF01                  NVARCHAR(50)
          ,@c_UDF02                  NVARCHAR(50)
          ,@n_Short                  FLOAT
          ,@n_Qty1                   FLOAT
          ,@n_Qty2                   FLOAT
          ,@c_MaxOrderLineNumber     NVARCHAR(5)
          
   CREATE TABLE #TMP_ORD (RowID INT NOT NULL IDENTITY(1,1), Orderkey NVARCHAR(10), OrderLineNumber NVARCHAR(5))
   
   CREATE NONCLUSTERED INDEX IDX_TMP_ORD ON #TMP_ORD (Orderkey, OrderLineNumber)
   
   CREATE TABLE #TMP_ORD_SUCCESS (RowID INT NOT NULL IDENTITY(1,1), Orderkey NVARCHAR(10))
   
   IF ISNULL(RTRIM(@c_OrderKey), '') <> ''  
   BEGIN  
      INSERT INTO #TMP_ORD (Orderkey, OrderLineNumber)  
      SELECT DISTINCT Orderkey, OrderLineNumber
      FROM ORDERDETAIL (NOLOCK)
      WHERE OrderKey = @c_OrderKey
   END
   ELSE IF ISNULL(RTRIM(@c_Loadkey), '') <> ''  
   BEGIN
      INSERT INTO #TMP_ORD (Orderkey, OrderLineNumber)  
      SELECT DISTINCT OD.Orderkey, OD.OrderLineNumber
      FROM LoadPlanDetail LPD (NOLOCK)
      JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = LPD.OrderKey
      JOIN ORDERDETAIL OD (NOLOCK) ON OD.OrderKey = OH.OrderKey
      WHERE (LPD.Loadkey = @c_Loadkey)  
      ORDER BY OD.Orderkey, OD.OrderLineNumber
   END 
   ELSE IF ISNULL(RTRIM(@c_Wavekey), '') <> ''  
   BEGIN
      INSERT INTO #TMP_ORD (Orderkey, OrderLineNumber)  
      SELECT DISTINCT OD.Orderkey, OD.OrderLineNumber
      FROM WaveDetail WD (NOLOCK)
      JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = WD.OrderKey
      JOIN ORDERDETAIL OD (NOLOCK) ON OD.OrderKey = OH.OrderKey
      WHERE (WD.Wavekey = @c_Wavekey)  
      ORDER BY OD.Orderkey, OD.OrderLineNumber
   END 
   ELSE 
   BEGIN      
      SELECT @n_Continue = 3      
      SELECT @n_Err = 64500      
      SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Loadkey, Wave and Orderkey are Blank (ispPRALC04)'  
      GOTO QUIT      
   END  
   
   SELECT @c_MaxOrderLineNumber = ISNULL(MAX(OrderLineNumber),'00000')
   FROM ORDERDETAIL WITH (NOLOCK)
   WHERE OrderKey = @c_OrderKey
                                                   
   DECLARE CUR_ORDER_LINES CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT OD.StorerKey, OD.OrderKey, OD.OrderLineNumber, OD.Sku, (OD.OpenQty - (OD.QtyAllocated + OD.QtyPicked))
                 , CL.Short, CL.UDF01, CL.UDF02
   FROM ORDERDETAIL OD (NOLOCK)
   JOIN #TMP_ORD t (NOLOCK) ON t.Orderkey = OD.OrderKey AND t.OrderLineNumber = OD.OrderLineNumber
   JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = OD.OrderKey
   JOIN CODELKUP CL (NOLOCK) ON CL.LISTNAME = 'SPLITORD' AND CL.Storerkey = OH.Storerkey 
                            AND CL.Code = OH.ConsigneeKey
   WHERE OH.UpdateSource = '0' AND OH.[Status] = '0'
   ORDER BY OD.OrderKey, OD.OrderLineNumber

   OPEN CUR_ORDER_LINES
   
   FETCH FROM CUR_ORDER_LINES INTO @c_StorerKey, @c_OrderKey, @c_OrderLineNumber, @c_SKU, @n_OpenQty
                                 , @c_Short, @c_UDF01, @c_UDF02                                       
      
   WHILE @@FETCH_STATUS = 0 AND @n_Continue IN(1,2)
   BEGIN   	   	             
      SET @n_Short = @c_Short
      
      --Check if CODELKUP.Short is a number
      IF ISNUMERIC(@c_Short) = 0
      BEGIN      
         SELECT @n_Continue = 3      
         SELECT @n_Err = 64505      
         SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': CODELKUP.Short is not a numeric value (ispPRALC04)'  
         GOTO QUIT      
      END  

      --Check if CODELKUP.Short is between 0 and 1
      IF @n_Short > 1 OR @n_Short < 0
      BEGIN      
         SELECT @n_Continue = 3      
         SELECT @n_Err = 64505      
         SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': CODELKUP.Short is not BETWEEN 0 AND 1 (ispPRALC04)'  
         GOTO QUIT      
      END  
      
      SET @n_Qty1 = CEILING(@n_OpenQty * @n_Short)
      SET @n_Qty2 = @n_OpenQty - @n_Qty1
      

      
      IF @b_debug = 1
         SELECT @c_StorerKey, @c_OrderKey, @c_OrderLineNumber, @c_SKU, @n_OpenQty, @n_Short
              , @n_Qty1, @n_Qty2
                                    
      --If @n_Qty2 > 0, need to split to next new line
      IF @n_Qty2 > 0
      BEGIN
         SELECT @c_MaxOrderLineNumber = CAST(@c_MaxOrderLineNumber AS INT) + 1

         INSERT INTO ORDERDETAIL
         (
            OrderKey, OrderLineNumber, ExternOrderKey, ExternLineNo,	Sku,	StorerKey,
            ManufacturerSku, RetailSku, AltSku, OriginalQty, OpenQty, UOM, PackKey, PickCode,	CartonGroup, Lot, 
             ID, Facility, UnitPrice, Tax01, Tax02, ExtendedPrice, UpdateSource, Lottable01,
            Lottable02, Lottable03, Lottable04, Lottable05,Lottable06,Lottable07, Lottable08, Lottable09, Lottable10,	
            Lottable11,Lottable12, Lottable13, Lottable14, Lottable15,EffectiveDate, TariffKey, FreeGoodQty,	GrossWeight, 
            Capacity, QtyToProcess, MinShelfLife, UserDefine01, UserDefine02, UserDefine03, UserDefine04, UserDefine05,
            UserDefine06, UserDefine07, UserDefine08, UserDefine09, POkey, ExternPOKey,UserDefine10, EnteredQTY,
            LoadKey, MBOLKey
            --OrderDetailSysId,ShippedQty, AdjustedQty, QtyPreAllocated, QtyAllocated, QtyPicked, AddDate, AddWho, EditDate, EditWho, TrafficCop, ArchiveCop,
            --[Status] 
         )
         SELECT @c_orderkey, RIGHT(REPLICATE('0',5) + @c_MaxOrderLineNumber,5), 
               OD.ExternOrderKey, OD.ExternLineNo,	OD.Sku,	OD.StorerKey,
               OD.ManufacturerSku, OD.RetailSku, OD.AltSku, @n_Qty2, @n_Qty2, OD.UOM, OD.PackKey, OD.PickCode,	OD.CartonGroup, OD.Lot,
               OD.ID, OD.Facility, OD.UnitPrice, OD.Tax01, OD.Tax02, OD.ExtendedPrice, OD.UpdateSource, OD.Lottable01,
               OD.Lottable02, OD.Lottable03, OD.Lottable04, OD.Lottable05, SUBSTRING(@c_UDF02,1,30) ,OD.Lottable07, OD.Lottable08, OD.Lottable09, OD.Lottable10, 
               OD.Lottable11,OD.Lottable12, OD.Lottable13, OD.Lottable14, OD.Lottable15, OD.EffectiveDate, OD.TariffKey, OD.FreeGoodQty, 
               OD.GrossWeight, OD.Capacity,OD.QtyToProcess, OD.MinShelfLife, OD.UserDefine01, OD.UserDefine02, OD.UserDefine03, OD.UserDefine04, 
               OD.UserDefine05,OD.UserDefine06, OD.UserDefine07, OD.UserDefine08, OD.UserDefine09, OD.POkey, OD.ExternPOKey, OD.UserDefine10, OD.EnteredQTY,
               OD.LoadKey, OD.MBOLKey
         FROM ORDERDETAIL OD (NOLOCK)
         JOIN #TMP_ORD ON (OD.Orderkey = #TMP_ORD.Orderkey AND OD.Orderlinenumber = #TMP_ORD.Orderlinenumber)
         WHERE OD.Orderkey = @c_orderkey AND OD.SKU = @c_SKU
         ORDER BY #TMP_ORD.Orderlinenumber
         
         SELECT @n_err = @@ERROR
         
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 64510
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Inserting Orderdetail Table. (ispPRALC04)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
            GOTO QUIT
         END		    	

         --Update Orderdetail Qty record
         UPDATE ORDERDETAIL WITH (ROWLOCK)
         SET OpenQty     = @n_Qty1
           , OriginalQty = @n_Qty1
           , Lottable06  = SUBSTRING(@c_UDF01,1,30)
         WHERE OrderKey = @c_OrderKey AND OrderLineNumber = @c_OrderLineNumber	  
         
         SELECT @n_err = @@ERROR
         
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 64515
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Updating Orderdetail Table. (ispPRALC04)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
            GOTO QUIT
         END	  
        
      END
           
      IF @n_err = 0
      BEGIN
         INSERT INTO #TMP_ORD_SUCCESS (Orderkey)
         SELECT @c_OrderKey
      END
      
NEXT_LOOP:
      FETCH FROM CUR_ORDER_LINES INTO @c_StorerKey, @c_OrderKey, @c_OrderLineNumber, @c_SKU, @n_OpenQty           
                                    , @c_Short, @c_UDF01, @c_UDF02                                                                                                                                 
   END -- CUR_ORDER_LINES   
   CLOSE CUR_ORDER_LINES
   DEALLOCATE CUR_ORDER_LINES
   
   --Update Orders.UpdateSource
   DECLARE CUR_ORDER CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT t.Orderkey
   FROM #TMP_ORD_SUCCESS t (NOLOCK)

   OPEN CUR_ORDER
   
   FETCH FROM CUR_ORDER INTO @c_OrderKey            
      
   WHILE @@FETCH_STATUS = 0 AND @n_Continue IN(1,2)
   BEGIN   	   	                                       
      UPDATE ORDERS WITH (ROWLOCK)
      SET UpdateSource = '1', TrafficCop = NULL
      WHERE OrderKey = @c_OrderKey
 
NEXT_LOOP_ORDERS:
      FETCH FROM CUR_ORDER INTO @c_OrderKey
                                                                                                                               
   END -- CUR_ORDER   
   CLOSE CUR_ORDER
   DEALLOCATE CUR_ORDER
 	
QUIT:
   IF CURSOR_STATUS('LOCAL', 'CUR_ORDER') IN (0 , 1)
   BEGIN
      CLOSE CUR_ORDER
      DEALLOCATE CUR_ORDER   
   END
      
   IF CURSOR_STATUS('LOCAL', 'CUR_ORDER_LINES') IN (0 , 1)
   BEGIN
      CLOSE CUR_ORDER_LINES
      DEALLOCATE CUR_ORDER_LINES   
   END
   
   IF OBJECT_ID('tempdb..#TMP_ORD') IS NOT NULL
      DROP TABLE #TMP_ORD
      
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
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispPRALC04'  
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