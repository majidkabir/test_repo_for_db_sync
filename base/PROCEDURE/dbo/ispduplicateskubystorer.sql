SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: ispDuplicateSKUByStorer                            */  
/* Creation Date: 04-Sep-2019                                           */  
/* Copyright: LFL                                                       */  
/* Written by: WLChooi                                                  */  
/*                                                                      */  
/* Purpose:  Duplicate SKU By Storer Level                              */
/*                                                                      */  
/* Called By:                                                           */    
/*                                                                      */
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/*11-fEB-2020   WLChooi  1.1  Pass in extra parameter to decide custom  */
/*                            value for columns repsectively (WL01)     */
/************************************************************************/  

CREATE PROCEDURE [dbo].[ispDuplicateSKUByStorer]
      @c_FromStorerkey     NVARCHAR(15)
   ,  @c_ToStorerkey       NVARCHAR(15)  
   ,  @c_SKU               NVARCHAR(20) 
   ,  @b_Success           INT           OUTPUT 
   ,  @n_Err               INT           OUTPUT 
   ,  @c_ErrMsg            NVARCHAR(250) OUTPUT
   ,  @c_CustomSQL         NVARCHAR(4000) = ''   --WL01
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE  @n_Continue            INT,
            @n_StartTCnt           INT,
            @c_ExecStatement       NVARCHAR(MAX),
            @c_SQLParm             NVARCHAR(MAX)             

   SELECT @n_continue = 1, @n_Err = 0, @b_Success = 1, @c_ErrMsg = '', @n_StartTCnt = @@TRANCOUNT

   IF ISNULL(@c_CustomSQL,'') = '' SET @c_CustomSQL = '' --WL01
   
   BEGIN TRAN

   IF @n_Continue IN (1,2)
   BEGIN
      INSERT INTO SKU ( [Storerkey]
                       ,[Sku]
                       ,[DESCR]
                       ,[SUSR1]
                       ,[SUSR2]
                       ,[SUSR3]
                       ,[SUSR4]
                       ,[SUSR5]
                       ,[MANUFACTURERSKU]
                       ,[RETAILSKU]
                       ,[ALTSKU]
                       ,[PACKKey]
                       ,[STDGROSSWGT]
                       ,[STDNETWGT]
                       ,[STDCUBE]
                       ,[TARE]
                       ,[CLASS]
                       ,[ACTIVE]
                       ,[SKUGROUP]
                       ,[Tariffkey]
                       ,[BUSR1]
                       ,[BUSR2]
                       ,[BUSR3]
                       ,[BUSR4]
                       ,[BUSR5]
                       ,[LOTTABLE01LABEL]
                       ,[LOTTABLE02LABEL]
                       ,[LOTTABLE03LABEL]
                       ,[LOTTABLE04LABEL]
                       ,[LOTTABLE05LABEL]
                       ,[NOTES1]
                       ,[NOTES2]
                       ,[PickCode]
                       ,[StrategyKey]
                       ,[CartonGroup]
                       ,[PutCode]
                       ,[PutawayLoc]
                       ,[PutawayZone]
                       ,[InnerPack]
                       ,[Cube]
                       ,[GrossWgt]
                       ,[NetWgt]
                       ,[ABC]
                       ,[CycleCountFrequency]
                       ,[LastCycleCount]
                       ,[ReorderPoint]
                       ,[ReorderQty]
                       ,[StdOrderCost]
                       ,[CarryCost]
                       ,[Price]
                       ,[Cost]
                       ,[ReceiptHoldCode]
                       ,[ReceiptInspectionLoc]
                       ,[OnReceiptCopyPackkey]
                       ,[TrafficCop]
                       ,[ArchiveCop]
                       ,[IOFlag]
                       ,[TareWeight]
                       ,[LotxIdDetailOtherlabel1]
                       ,[LotxIdDetailOtherlabel2]
                       ,[LotxIdDetailOtherlabel3]
                       ,[AvgCaseWeight]
                       ,[TolerancePct]
                       ,[SkuStatus]
                       ,[Length]
                       ,[Width]
                       ,[Height]
                       ,[weight]
                       ,[itemclass]
                       ,[ShelfLife]
                       ,[Facility]
                       ,[BUSR6]
                       ,[BUSR7]
                       ,[BUSR8]
                       ,[BUSR9]
                       ,[BUSR10]
                       ,[ReturnLoc]
                       ,[ReceiptLoc]
                       ,[archiveqty]
                       ,[XDockReceiptLoc]
                       ,[PrePackIndicator]
                       ,[PackQtyIndicator]
                       ,[StackFactor]
                       ,[IVAS]
                       ,[OVAS]
                       ,[Style]
                       ,[Color]
                       ,[Size]
                       ,[Measurement]
                       ,[HazardousFlag]
                       ,[TemperatureFlag]
                       ,[ProductModel]
                       ,[CtnPickQty]
                       ,[CountryOfOrigin]
                       ,[IB_UOM]
                       ,[IB_RPT_UOM]
                       ,[OB_UOM]
                       ,[OB_RPT_UOM]
                       ,[ABCPL]
                       ,[ABCCS]
                       ,[ABCEA]
                       ,[DisableABCCalc]
                       ,[ABCPeriod]
                       ,[ABCStorerkey]
                       ,[ABCSku]
                       ,[OldStorerkey]
                       ,[OldSku]
                       ,[ImageFolder]
                       ,[OTM_SKUGroup]
                       ,[LOTTABLE06LABEL]
                       ,[LOTTABLE07LABEL]
                       ,[LOTTABLE08LABEL]
                       ,[LOTTABLE09LABEL]
                       ,[LOTTABLE10LABEL]
                       ,[LOTTABLE11LABEL]
                       ,[LOTTABLE12LABEL]
                       ,[LOTTABLE13LABEL]
                       ,[LOTTABLE14LABEL]
                       ,[LOTTABLE15LABEL]
                       ,[LottableCode]
                       ,[Pressure]
                       ,[SerialNoCapture]
                       ,[DataCapture] )
      SELECT            @c_ToStorerkey
                       ,[Sku]
                       ,[DESCR]
                       ,[SUSR1]
                       ,[SUSR2]
                       ,[SUSR3]
                       ,[SUSR4]
                       ,[SUSR5]
                       ,[MANUFACTURERSKU]
                       ,[RETAILSKU]
                       ,[ALTSKU]
                       ,[PACKKey]
                       ,[STDGROSSWGT]
                       ,[STDNETWGT]
                       ,[STDCUBE]
                       ,[TARE]
                       ,[CLASS]
                       ,[ACTIVE]
                       ,[SKUGROUP]
                       ,[Tariffkey]
                       ,[BUSR1]
                       ,[BUSR2]
                       ,[BUSR3]
                       ,[BUSR4]
                       ,[BUSR5]
                       ,[LOTTABLE01LABEL]
                       ,[LOTTABLE02LABEL]
                       ,[LOTTABLE03LABEL]
                       ,[LOTTABLE04LABEL]
                       ,[LOTTABLE05LABEL]
                       ,[NOTES1]
                       ,[NOTES2]
                       ,[PickCode]
                       ,[StrategyKey]
                       ,[CartonGroup]
                       ,[PutCode]
                       ,[PutawayLoc]
                       ,[PutawayZone]
                       ,[InnerPack]
                       ,[Cube]
                       ,[GrossWgt]
                       ,[NetWgt]
                       ,[ABC]
                       ,[CycleCountFrequency]
                       ,[LastCycleCount]
                       ,[ReorderPoint]
                       ,[ReorderQty]
                       ,[StdOrderCost]
                       ,[CarryCost]
                       ,[Price]
                       ,[Cost]
                       ,[ReceiptHoldCode]
                       ,[ReceiptInspectionLoc]
                       ,[OnReceiptCopyPackkey]
                       ,[TrafficCop]
                       ,[ArchiveCop]
                       ,[IOFlag]
                       ,[TareWeight]
                       ,[LotxIdDetailOtherlabel1]
                       ,[LotxIdDetailOtherlabel2]
                       ,[LotxIdDetailOtherlabel3]
                       ,[AvgCaseWeight]
                       ,[TolerancePct]
                       ,[SkuStatus]
                       ,[Length]
                       ,[Width]
                       ,[Height]
                       ,[weight]
                       ,[itemclass]
                       ,[ShelfLife]
                       ,[Facility]
                       ,[BUSR6]
                       ,[BUSR7]
                       ,[BUSR8]
                       ,[BUSR9]
                       ,[BUSR10]
                       ,[ReturnLoc]
                       ,[ReceiptLoc]
                       ,[archiveqty]
                       ,[XDockReceiptLoc]
                       ,[PrePackIndicator]
                       ,[PackQtyIndicator]
                       ,[StackFactor]
                       ,[IVAS]
                       ,[OVAS]
                       ,[Style]
                       ,[Color]
                       ,[Size]
                       ,[Measurement]
                       ,[HazardousFlag]
                       ,[TemperatureFlag]
                       ,[ProductModel]
                       ,[CtnPickQty]
                       ,[CountryOfOrigin]
                       ,[IB_UOM]
                       ,[IB_RPT_UOM]
                       ,[OB_UOM]
                       ,[OB_RPT_UOM]
                       ,[ABCPL]
                       ,[ABCCS]
                       ,[ABCEA]
                       ,[DisableABCCalc]
                       ,[ABCPeriod]
                       ,[ABCStorerkey]
                       ,[ABCSku]
                       ,[OldStorerkey]
                       ,[OldSku]
                       ,[ImageFolder]
                       ,[OTM_SKUGroup]
                       ,[LOTTABLE06LABEL]
                       ,[LOTTABLE07LABEL]
                       ,[LOTTABLE08LABEL]
                       ,[LOTTABLE09LABEL]
                       ,[LOTTABLE10LABEL]
                       ,[LOTTABLE11LABEL]
                       ,[LOTTABLE12LABEL]
                       ,[LOTTABLE13LABEL]
                       ,[LOTTABLE14LABEL]
                       ,[LOTTABLE15LABEL]
                       ,[LottableCode]
                       ,[Pressure]
                       ,[SerialNoCapture]
                       ,[DataCapture]
      FROM SKU (NOLOCK)
      WHERE Storerkey = @c_FromStorerkey
      AND SKU = @c_SKU

      SELECT @n_Err = @@ERROR

      IF @n_Err <> 0  
      BEGIN  
         SET @n_continue = 3  
         SET @n_err = 70000  
         SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Inserting to SKU Table. (ispDuplicateSKUByStorer)'   
                     + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
         ROLLBACK TRAN   
         GOTO QUIT  
      END 

      --WL01 Start
      IF @c_CustomSQL <> ''
      BEGIN
         SET @c_ExecStatement = N'UPDATE SKU '
                               + 'SET ' + @c_CustomSQL + ' , TrafficCop = NULL '
                               + 'WHERE Storerkey = @c_ToStorerkey AND SKU = @c_sku '

         SET @c_SQLParm =  N'@c_ToStorerkey NVARCHAR(15), @c_sku NVARCHAR(20)  '
        
         EXEC sp_executesql @c_ExecStatement, @c_SQLParm, @c_ToStorerkey, @c_sku
      END
      --WL01 END
   END

QUIT:
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
  
      --EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispDuplicateSKUByStorer'  
      --RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
   END  
   ELSE  
   BEGIN  
      SET @b_Success = 1  
      WHILE @@TRANCOUNT > @n_StartTCnt  
      BEGIN  
         COMMIT TRAN  
      END  
   END  
    
   WHILE @@TRANCOUNT < @n_StartTCnt   
      BEGIN TRAN;     


END -- End Procedure

GO