SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Stored Procedure: ispPOANF03                                         */    
/* Creation Date: 07-Feb-2014                                           */    
/* Copyright: LFL                                                       */    
/* Written by: Chee Jun Yan                                             */    
/*                                                                      */    
/* Purpose: Alter OpenQty back to original to fulfill unallocated       */
/*          orders (DCToDC)                                             */
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
/* Date         Author   Ver  Purposes                                  */ 
/* 2014-06-30   CSCHONG  1.0  SQL2012 Fixing Bugs (CS01)                */    
/* 2015-09-22   NJOW01   1.1  329253-if all enteredqty are fulfill no   */
/*                            need to proceed for the sku               */
/************************************************************************/    
CREATE  PROC [dbo].[ispPOANF03]        
    @c_LoadKey                      NVARCHAR(10)
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
      @n_StartTCnt   INT

   DECLARE 
      @c_LoadType           NVARCHAR(20),
      @c_OrderKey           NVARCHAR(10),
      @c_OrderLineNumber    NVARCHAR(5),
      @n_QtyVariance        INT,
      @n_QtyLeftToFulfill   INT,
      @n_PickQty            INT,
      @c_Facility           NVARCHAR(5),     
      @c_StorerKey          NVARCHAR(15),     
      @c_SKU                NVARCHAR(20),    
      @c_Lottable01         NVARCHAR(18),    
      @c_Lottable02         NVARCHAR(18),    
      @c_Lottable03         NVARCHAR(18),
      @n_RemainingQty       INT,
      @c_NewOrderKey        NVARCHAR(10),
      @c_NewOrderLineNumber NVARCHAR(5),
      @n_UOMQty             INT

   DECLARE
      @c_PickDetailKey    NVARCHAR(18), 
      @c_CaseID           NVARCHAR(20), 
      @c_PickHeaderKey    NVARCHAR(18), 
      @c_Lot              NVARCHAR(10), 
      @n_Qty              INT, 
      @c_Loc              NVARCHAR(10), 
      @c_Id               NVARCHAR(18),
      @c_PackKey          NVARCHAR(10), 
      @c_CartonGroup      NVARCHAR(10), 
      @c_DoReplenish      NVARCHAR(1), 
      @c_replenishzone    NVARCHAR(10), 
      @c_doCartonize      NVARCHAR(1), 
      @c_PickMethod       NVARCHAR(1),
      @c_DropID           NVARCHAR(20)

   SELECT @n_StartTCnt = @@TRANCOUNT , @n_Continue=1, @b_Success=1, @n_Err=0, @c_ErrMsg=''

   SET @n_QtyLeftToFulfill = 0

   -- GET LoadType FROM LoadPlan
   SELECT TOP 1 
      @c_LoadType = O.Type
   FROM LOADPLANDETAIL LPD WITH (NOLOCK) 
   JOIN ORDERS O WITH (NOLOCK) ON (LPD.OrderKey = O.OrderKey)
   WHERE LPD.LoadKey = @c_LoadKey

   -- SKIP THIS STEP IF Not DCToDC
   IF ISNULL(@c_LoadType,'') <> 'DCToDC'
      GOTO Quit

   -- Get all Unallocated Orderdetail
   DECLARE CURSOR_UNALLOCATED_ORDERS CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
   SELECT
      OD.SKU, 
      OD.StorerKey, 
      OD.Facility,  
      OD.Lottable01,  
      OD.Lottable02,  
      OD.Lottable03,
      SUM(OD.OpenQty - (OD.QtyAllocated + OD.QtyPreAllocated + OD.QtyPicked ))
   FROM ORDERDETAIL OD WITH (NOLOCK)  
   JOIN ORDERS O WITH (NOLOCK) ON O.OrderKey = OD.OrderKey
   JOIN LoadPlanDetail LPD WITH (NOLOCK) ON OD.OrderKey = LPD.OrderKey
   WHERE LPD.LoadKey = @c_LoadKey   
     AND O.Type NOT IN ( 'M', 'I' )   
     AND O.SOStatus <> 'CANC'   
     AND O.Status < '9'   
     AND (OD.OpenQty - ( OD.QtyAllocated + OD.QtyPreAllocated + OD.QtyPicked )) > 0
   GROUP BY OD.SKU, OD.StorerKey, OD.Facility, OD.Lottable01, OD.Lottable02, OD.Lottable03 

   OPEN CURSOR_UNALLOCATED_ORDERS               
   FETCH NEXT FROM CURSOR_UNALLOCATED_ORDERS INTO 
      @c_SKU, @c_StorerKey, @c_Facility, @c_Lottable01, @c_Lottable02, @c_Lottable03, @n_QtyLeftToFulfill
          
   WHILE (@@FETCH_STATUS <> -1)
   BEGIN 
      IF @b_debug = 1
         PRINT '-------------------------------------------------' + CHAR(13) +
               'StorerKey: ' + @c_StorerKey + CHAR(13) +
               'SKU: ' + @c_SKU + CHAR(13) +
               'Facility: ' + @c_Facility + CHAR(13) +
               'Lottable01: ' + @c_Lottable01 + CHAR(13) +
               'Lottable02: ' + @c_Lottable02 + CHAR(13) +
               'Lottable03: ' + @c_Lottable03 + CHAR(13) + 
               '@n_QtyLeftToFulfill: ' + CAST(@n_QtyLeftToFulfill AS NVARCHAR) + CHAR(13) 
      
      --NJOW01
      IF NOT EXISTS ( SELECT 1                    
                      FROM ORDERDETAIL OD WITH (NOLOCK)                                                                    
                      JOIN ORDERS O WITH (NOLOCK) ON O.OrderKey = OD.OrderKey                                              
                      JOIN LoadPlanDetail LPD WITH (NOLOCK) ON OD.OrderKey = LPD.OrderKey                                  
                      WHERE LPD.LoadKey = @c_LoadKey                                                                       
                        AND O.Type NOT IN ( 'M', 'I' )                                                                     
                        AND O.SOStatus <> 'CANC'                                                                           
                        AND O.Status < '9'                                                                                 
                        AND (OD.EnteredQty - ( OD.QtyAllocated + OD.QtyPreAllocated + OD.QtyPicked )) > 0                  
                        AND OD.SKU = @c_SKU                                                                                
                        AND OD.StorerKey = @c_StorerKey                                                                    
                        AND OD.Facility = @c_Facility                                                                      
                        AND OD.Lottable01 = @c_Lottable01                                                                  
                        AND OD.Lottable02 = @c_Lottable02                                                                  
                        AND OD.Lottable03 = @c_Lottable03)    
      BEGIN
      	 GOTO NEXT_REC
      END                                                              
                                                                                                             
      WHILE @n_QtyLeftToFulfill > 0
      BEGIN
         -- Get Orderdetail with altered openqty  
         SELECT @c_OrderKey = '', @c_OrderLineNumber = '', @n_QtyVariance = 0  
         SELECT TOP 1   
            @c_OrderKey = OD.OrderKey,   
            @c_OrderLineNumber = OD.OrderLineNumber,  
            @n_QtyVariance = OD.QtyAllocated - OD.EnteredQty  
         FROM ORDERDETAIL OD WITH (NOLOCK)    
         JOIN ORDERS O WITH (NOLOCK) ON O.OrderKey = OD.OrderKey  
         JOIN LoadPlanDetail LPD WITH (NOLOCK) ON OD.OrderKey = LPD.OrderKey  
         WHERE LPD.LoadKey = @c_LoadKey     
           AND O.Type NOT IN ( 'M', 'I' )     
           AND O.SOStatus <> 'CANC'     
           AND O.Status < '9'     
           AND OD.QtyAllocated > OD.EnteredQty  
           AND OD.SKU = @c_SKU  
           AND OD.StorerKey = @c_StorerKey  
           AND OD.Facility = @c_Facility  
           AND OD.Lottable01 = @c_Lottable01  
           AND OD.Lottable02 = @c_Lottable02  
           AND OD.Lottable03 = @c_Lottable03  
         ORDER BY OD.QtyAllocated - OD.EnteredQty  

         IF @n_QtyVariance = 0  
         BEGIN
            PRINT 'No order selected for SKU:' + @c_SKU
            BREAK
         END
           
         IF @n_QtyVariance > @n_QtyLeftToFulfill  
            SET @n_QtyVariance = @n_QtyLeftToFulfill  

         IF @b_Debug = 1  
            PRINT 'OrderKey: ' + @c_OrderKey + ', OrderLineNumber: '  + @c_OrderLineNumber  + 
                  ', QtyVariance: ' + CAST(@n_QtyVariance AS NVARCHAR) + CHAR(13)         

         -- Unallocate Orderdetail with altered openqty and allocate unallocated orderdetail  
         DECLARE CURSOR_UNALLOCATE_PICKDETAIL CURSOR FAST_FORWARD READ_ONLY FOR   
         SELECT  
            PickDetailKey, CaseID, PickHeaderKey, Lot, UOM, UOMQty, Qty, Loc, Id,  
           PackKey, CartonGroup, DoReplenish, replenishzone, doCartonize, PickMethod, DropID  
         FROM PickDetail WITH (NOLOCK)  
         WHERE Orderkey = @c_OrderKey  
           AND OrderLineNumber = @c_OrderLineNumber  
         ORDER BY Qty DESC  

         OPEN CURSOR_UNALLOCATE_PICKDETAIL                 
         FETCH NEXT FROM CURSOR_UNALLOCATE_PICKDETAIL INTO   
            @c_PickDetailKey, @c_CaseID, @c_PickHeaderKey, @c_Lot, @c_UOM, @n_UOMQty, @n_Qty, @c_Loc, @c_Id,  
            @c_PackKey, @c_CartonGroup, @c_DoReplenish, @c_replenishzone, @c_doCartonize, @c_PickMethod, @c_DropID 

         WHILE (@@FETCH_STATUS <> -1 AND @n_QtyVariance > 0)            
         BEGIN   
            SET @n_PickQty = 0  
            IF @n_QtyVariance < @n_Qty  
            BEGIN  
               UPDATE PickDetail WITH (ROWLOCK)
               SET Qty = Qty - @n_QtyVariance  
               WHERE PickDetailKey = @c_PickDetailKey  

               IF @@ERROR <> 0  
               BEGIN  
                  SET @n_Continue = 3  
                  SET @n_Err = 14000  
                  SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) +   
                                  ': Update PickDetail Failed. (ispPOANF03)'  
                  GOTO Quit  
               END  

               SET @n_PickQty = @n_QtyVariance  
               SET @n_QtyVariance = 0  
            END  
            ELSE  
            BEGIN  
               DELETE FROM PickDetail  
               WHERE PickDetailKey = @c_PickDetailKey  

               IF @@ERROR <> 0  
               BEGIN  
                  SET @n_Continue = 3  
                  SET @n_Err = 14001 
                  SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) +   
                                  ': Delete PickDetail Failed. (ispPOANF03)'  
                  GOTO Quit  
               END  

               SET @n_PickQty = @n_Qty  
               SET @n_QtyVariance = @n_QtyVariance - @n_Qty  
            END  

            IF @b_Debug = 1  
               PRINT 'Unallocate PickDetailKey: ' + @c_PickDetailKey + ', Qty: ' + CAST(@n_PickQty AS NVARCHAR) + CHAR(13) 

            WHILE @n_PickQty > 0
            BEGIN
               -- Get Unallocated OrderKey
               SELECT @c_NewOrderKey = '', @c_NewOrderLineNumber = '', @n_RemainingQty = 0
               SELECT TOP 1   
                  @c_NewOrderKey = OD.OrderKey,   
                  @c_NewOrderLineNumber = OD.OrderLineNumber,
                  @n_RemainingQty = OD.EnteredQty - ( OD.QtyAllocated + OD.QtyPreAllocated + OD.QtyPicked )
               FROM ORDERDETAIL OD WITH (NOLOCK)    
               JOIN ORDERS O WITH (NOLOCK) ON O.OrderKey = OD.OrderKey  
               JOIN LoadPlanDetail LPD WITH (NOLOCK) ON OD.OrderKey = LPD.OrderKey  
               WHERE LPD.LoadKey = @c_LoadKey     
                 AND O.Type NOT IN ( 'M', 'I' )   
                 AND O.SOStatus <> 'CANC'   
                 AND O.Status < '9'   
                 AND (OD.EnteredQty - ( OD.QtyAllocated + OD.QtyPreAllocated + OD.QtyPicked )) > 0
                 AND OD.SKU = @c_SKU  
                 AND OD.StorerKey = @c_StorerKey  
                 AND OD.Facility = @c_Facility  
                 AND OD.Lottable01 = @c_Lottable01  
                 AND OD.Lottable02 = @c_Lottable02  
                 AND OD.Lottable03 = @c_Lottable03

               IF @b_Debug = 1  
                  PRINT 'NewOrderKey: ' + @c_NewOrderKey + ', NewOrderLineNumber: '  + @c_NewOrderLineNumber  + 
                        ', QtyToAllocate: ' + CAST(@n_RemainingQty AS NVARCHAR) + CHAR(13)  

               IF @n_RemainingQty = 0
                  BREAK 

               IF @n_RemainingQty > @n_PickQty  
                  SET @n_RemainingQty = @n_PickQty  

               -- INSERT PickDetail  
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
                  SET @n_Err = 14002  
                  SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) +   
                                  ': Get PickDetailKey Failed. (ispPOANF03)'  
                  GOTO Quit  
               END  
               ELSE  
               BEGIN  
                  INSERT PICKDETAIL (    
                      PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber,    
                      Lot, StorerKey, Sku, UOM, UOMQty, Qty,   
                      Loc, Id, PackKey, CartonGroup, DoReplenish,    
                      replenishzone, doCartonize, PickMethod, DropID  
                  ) VALUES (    
                      @c_PickDetailKey, @c_CaseID, @c_PickHeaderKey, @c_NewOrderKey, @c_NewOrderLineNumber,    
                      @c_Lot, @c_StorerKey, @c_SKU, @c_UOM, @n_UOMQty, @n_RemainingQty,   
                      @c_Loc, @c_Id, @c_PackKey, @c_CartonGroup, @c_DoReplenish,   
                      @c_replenishzone, @c_doCartonize, @c_PickMethod, @c_DropID 
                  )   
  
                  IF @@ERROR <> 0  
                  BEGIN  
                     SET @n_Continue = 3  
                     SET @n_Err = 14003  
                     SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) +   
                                     ': Insert PickDetail Failed. (ispPOANF03)'  
                     GOTO Quit  
                  END  
               END -- IF @b_Success = 1  
  
               IF @b_Debug = 1  
                  PRINT 'Allocate New PickDetailKey: ' + @c_PickDetailKey + ', Qty: ' + CAST(@n_RemainingQty AS NVARCHAR) + CHAR(13) 

               SET @n_PickQty = @n_PickQty - @n_RemainingQty
            END -- WHILE @n_PickQty > 0
 
            SET @n_QtyLeftToFulfill = @n_QtyLeftToFulfill - @n_PickQty  

            FETCH NEXT FROM CURSOR_UNALLOCATE_PICKDETAIL INTO   
               @c_PickDetailKey, @c_CaseID, @c_PickHeaderKey, @c_Lot, @c_UOM, @n_UOMQty, @n_Qty, @c_Loc, @c_Id,  
               @c_PackKey, @c_CartonGroup, @c_DoReplenish, @c_replenishzone, @c_doCartonize, @c_PickMethod, @c_DropID   
         END -- WHILE (@@FETCH_STATUS <> -1 AND @n_PickQty > 0)     

         CLOSE CURSOR_UNALLOCATE_PICKDETAIL  
         DEALLOCATE CURSOR_UNALLOCATE_PICKDETAIL  
      END -- WHILE @n_QtyLeftToFulfill > 0
      
      NEXT_REC:

      FETCH NEXT FROM CURSOR_UNALLOCATED_ORDERS INTO 
         @c_SKU, @c_StorerKey, @c_Facility, @c_Lottable01, @c_Lottable02, @c_Lottable03, @n_QtyLeftToFulfill
   END -- END WHILE FOR CURSOR_UNALLOCATED_ORDERS
   CLOSE CURSOR_UNALLOCATED_ORDERS
   DEALLOCATE CURSOR_UNALLOCATED_ORDERS

QUIT:
   IF (SELECT CURSOR_STATUS('LOCAL','CURSOR_UNALLOCATED_ORDERS')) >=0 
   BEGIN
      CLOSE CURSOR_UNALLOCATED_ORDERS           
      DEALLOCATE CURSOR_UNALLOCATED_ORDERS      
   END

   IF (SELECT CURSOR_STATUS('LOCAL','CURSOR_UNALLOCATE_PICKDETAIL')) >=0 
   BEGIN
      CLOSE CURSOR_UNALLOCATE_PICKDETAIL           
      DEALLOCATE CURSOR_UNALLOCATE_PICKDETAIL      
   END

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
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispPOANF03'  
		RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012 
      --RAISERROR @n_Err @c_ErrMsg  
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