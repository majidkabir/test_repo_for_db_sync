SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Store Procedure:  ispPostECReceipt                                   */    
/* Creation Date:  03-Aug-2015                                          */    
/* Copyright: IDS                                                       */    
/* Written by:  Barnett                                                 */    
/*                                                                      */    
/* Purpose:  Post EC Receipt to WMS Receipt Table                       */    
/*                                                                      */    
/* Input Parameters:  @n_ECReceiptKey                                   */    
/*                                                                      */    
/* Output Parameters:  None                                             */    
/*                                                                      */    
/* Return Status:  None                                                 */    
/*                                                                      */    
/* Usage:                                                               */    
/*                                                                      */    
/* Local Variables:                                                     */    
/*                                                                      */    
/* Called By: EWMS                                                      */    
/*                                                                      */    
/* PVCS Version: 1.0                                                    */    
/*                                                                      */    
/* Version: 5.4                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author    Purposes                                      */  
/* 2015-08-03   Barnett   Initial Development                           */    
/************************************************************************/    
CREATE PROC [dbo].[ispPostECReceipt] (    
   @n_ECReceiptKey   NVARCHAR(50),     
   @n_UserName       NVARCHAR(50)    
)  
AS     
BEGIN    
   SET NOCOUNT ON    
    
   DECLARE  @c_ExternReceiptKey     NVARCHAR(20),    
            @n_ReceiptKey           NVARCHAR(25),  
            @n_StartTCnt            INT,          
            @n_Continue             INT,     
            @c_Status               NVARCHAR(10),  
            @c_PCCDeliveryTime      NVARCHAR(30),             
            @c_StorerKey            NVARCHAR(15),  
            @b_Success              INT,    
            @n_err                  INT,    
            @c_errmsg               NVARCHAR(215)  
             
    
   SET @n_StartTCnt=@@TRANCOUNT     
   SET @n_Continue=1     
   SET @b_success = 1  
   SET @n_ReceiptKey = ''  
  
   SELECT @c_ExternReceiptKey = ECR.ExternReceiptKey,  
          @c_StorerKey = ECR.StorerKey,  
          @c_PCCDeliveryTime = CLP.Description  
   FROM EC_Receipt ECR WITH (NOLOCk)   
   LEFt OUTER JOIN CodelKup CLP WITH (NOLOCK) ON CLP.ListName = 'ASNHUDF07' AND CLP.Code = ECR.PCCDeliveryTime  
   WHERE ECR.ReceiptKey = @n_ECReceiptKey and ECR.Status = '0'  
     
  
   IF ISNULL( RTRIM(@n_ECReceiptKey), '') = ''    
   BEGIN    
         SELECT @n_ReceiptKey  = ReceiptKey,  
                @c_Status = Status  
         FROM   Receipt WITH (NOLOCK)    
         WHERE  StorerKey = @c_StorerKey    
         AND    ExternReceiptKey = @c_ExternReceiptKey           
         --AND    STATUS NOT IN ('9','CANC')  -- To skip the Shipped or Cancel orders added by Ricky July 1st, 2008   
   END    
  
   ----------------------  
   BEGIN TRANSACTION  
   ----------------------  
  
   IF ISNULL( RTRIM(@n_ReceiptKey), '') <> ''    
   BEGIN     
      IF EXISTS(SELECT 1 FROM Receipt WITH (NOLOCK) WHERE ReceiptKey = @n_ReceiptKey )    
      BEGIN    
             
         IF (@c_Status BETWEEN '1' AND '9') OR (@c_Status = 'CANC')    
         BEGIN    
            SET @b_success = 0    
            SET @n_err = 60001    
            SET @c_errmsg = 'Receipt # :' + RTRIM(@c_ExternReceiptKey) + ' Already Processed/Cancel. No Update Allow'    
            GOTO QUIT     
         END     
    
         --Update the EC-Receipt record to Status 'E' 'Error'  
         UPDATE EC_Receipt  
         SET Status = 'E'     
         WHERE  ReceiptKey = @n_ECReceiptKey  
  
         SET @n_Err = @@ERROR    
         IF @n_Err <> 0     
         BEGIN    
            SET @n_Continue = 3    
            SET @b_success = 0    
            SET @n_err = 60002   
            SET @c_ErrMsg = 'Update EC_Receipt Status to Error Failed!'    
            GOTO QUIT    
         END    
      END     
   END     
  
    
--   IF ISNULL( RTRIM(@n_ReceiptKey), '') = ''     
--   BEGIN    
--      -- get Next Order Number from nCounter    
--      SET @b_success = 1    
--    
--      EXECUTE dbo.nspg_getkey     
--          'RECEIPT' ,     
--           10 ,     
--           @n_ReceiptKey OUTPUT ,     
--           @b_success  OUTPUT,     
--           @n_err      OUTPUT,     
--           @c_errmsg   OUTPUT       
--   END       
--     
--   IF @n_ReceiptKey = 0     
--   BEGIN    
--      SET @n_Continue = 3    
--      SET @b_success = 0    
--      SET @n_err = 60003   
--      SET @c_ErrMsg = 'Failed to Get New Receipt Key!'    
--      GOTO QUIT    
--   END    
--     
  
     
   IF NOT EXISTS(SELECT 1 FROM Receipt WITH (NOLOCK) WHERE ReceiptKey = @n_ReceiptKey)    
   BEGIN     
  
      -- Post to  New Receipt        
      INSERT Receipt(ReceiptKey,ExternReceiptKey,ReceiptGroup,StorerKey,ReceiptDate,POKey,CarrierKey,CarrierName,CarrierAddress1,CarrierAddress2  
            ,CarrierCity,CarrierState,CarrierZip,CarrierReference,WarehouseReference,OriginCountry,DestinationCountry,VehicleNumber,VehicleDate  
            ,PlaceOfLoading,PlaceOfDischarge,PlaceofDelivery,IncoTerms,TermsNote,ContainerKey,Signatory,PlaceofIssue,OpenQty,Status,Notes,EffectiveDate  
            ,AddDate,AddWho,EditDate,EditWho,TrafficCop,ArchiveCop,ContainerType,ContainerQty,BilledContainerQty,RECType,ASNStatus,ASNReason,Facility  
            ,MBOLKey,Appointment_No,LoadKey,xDockFlag,UserDefine01,PROCESSTYPE,UserDefine02,UserDefine03,UserDefine04,UserDefine05,UserDefine06  
            ,UserDefine07,UserDefine08,UserDefine09,UserDefine10,DOCTYPE,RoutingTool,CTNTYPE1,CTNTYPE2,CTNTYPE3,CTNTYPE4,CTNTYPE5,CTNTYPE6,CTNTYPE7  
            ,CTNTYPE8,CTNTYPE9,CTNTYPE10,PACKTYPE1,PACKTYPE2,PACKTYPE3,PACKTYPE4,PACKTYPE5,PACKTYPE6,PACKTYPE7,PACKTYPE8,PACKTYPE9,PACKTYPE10,CTNCNT1  
            ,CTNCNT2,CTNCNT3,CTNCNT4,CTNCNT5,CTNCNT6,CTNCNT7,CTNCNT8,CTNCNT9,CTNCNT10,CTNQTY1,CTNQTY2,CTNQTY3,CTNQTY4,CTNQTY5,CTNQTY6,CTNQTY7,CTNQTY8  
            ,CTNQTY9,CTNQTY10,NoOfMasterCtn,NoOfTTLUnit,NoOfPallet,Weight,WeightUnit,[Cube],CubeUnit,GIS_ControlNo,Cust_ISA_ControlNo,Cust_GIS_ControlNo  
            ,GIS_ProcessTime,Cust_EDIAckTime,FinalizeDate,SellerName,SellerCompany,SellerAddress1,SellerAddress2,SellerAddress3,SellerAddress4  
            ,SellerCity,SellerState,SellerZip,SellerCountry,SellerContact1,SellerContact2,SellerPhone1,SellerPhone2,SellerEmail1,SellerEmail2  
      ,SellerFax1,SellerFax2)  
      SELECT ReceiptKey,ExternReceiptKey,ReceiptGroup,StorerKey,ReceiptDate,POKey,CarrierKey,CarrierName,CarrierAddress1,CarrierAddress2  
            ,CarrierCity,CarrierState,CarrierZip,CarrierReference,WarehouseReference,OriginCountry,DestinationCountry,VehicleNumber,VehicleDate  
            ,PlaceOfLoading,PlaceOfDischarge,PlaceofDelivery,IncoTerms,TermsNote,ContainerKey,Signatory,PlaceofIssue,OpenQty,Status,Notes,EffectiveDate  
            ,Getdate(), @n_UserName, GetDate(), @n_UserName,TrafficCop,ArchiveCop,ContainerType,ContainerQty,BilledContainerQty,RECType,ASNStatus,ASNReason,Facility  
            ,MBOLKey,Appointment_No,LoadKey,xDockFlag,UserDefine01,PROCESSTYPE,UserDefine02,UserDefine03,UserDefine04,UserDefine05,UserDefine06  
            ,UserDefine07 + ISNULL(@c_PCCDeliveryTime, '00:00:00'),UserDefine08,UserDefine09,UserDefine10,DOCTYPE,RoutingTool,CTNTYPE1,CTNTYPE2,CTNTYPE3,CTNTYPE4,CTNTYPE5,CTNTYPE6,CTNTYPE7  
            ,CTNTYPE8,CTNTYPE9,CTNTYPE10,PACKTYPE1,PACKTYPE2,PACKTYPE3,PACKTYPE4,PACKTYPE5,PACKTYPE6,PACKTYPE7,PACKTYPE8,PACKTYPE9,PACKTYPE10,CTNCNT1  
            ,CTNCNT2,CTNCNT3,CTNCNT4,CTNCNT5,CTNCNT6,CTNCNT7,CTNCNT8,CTNCNT9,CTNCNT10,CTNQTY1,CTNQTY2,CTNQTY3,CTNQTY4,CTNQTY5,CTNQTY6,CTNQTY7,CTNQTY8  
            ,CTNQTY9,CTNQTY10,NoOfMasterCtn,NoOfTTLUnit,NoOfPallet,Weight,WeightUnit,[Cube],CubeUnit,GIS_ControlNo,Cust_ISA_ControlNo,Cust_GIS_ControlNo  
            ,GIS_ProcessTime,Cust_EDIAckTime,FinalizeDate,SellerName,SellerCompany,SellerAddress1,SellerAddress2,SellerAddress3,SellerAddress4  
            ,SellerCity,SellerState,SellerZip,SellerCountry,SellerContact1,SellerContact2,SellerPhone1,SellerPhone2,SellerEmail1,SellerEmail2  
            ,SellerFax1,SellerFax2  
      FROM EC_Receipt  
      WHERE ReceiptKey = @n_ECReceiptKey  
  
       
      --Check Error    
      SET @n_Err = @@ERROR    
  
      IF @n_Err <> 0     
      BEGIN    
         SET @n_Continue = 3    
         SET @b_success = 0    
         SET @c_ErrMsg = 'Insert Receipt Failed!'    
         GOTO QUIT    
      END    
      ELSE    
      BEGIN    
  
         UPDATE EC_Receipt    
         SET Status='9'  
                --RefReceiptKey = @n_ReceiptKey  
                --ReceiptKey = @n_ReceiptKey,  
                --RefReceiptKey = @n_ECReceiptKey  
         WHERE ReceiptKey = @n_ECReceiptKey     
  
         SET @n_Err = @@ERROR    
         IF @n_Err <> 0     
         BEGIN    
            SET @n_Continue = 3    
            SET @b_success = 0    
            SET @c_ErrMsg = 'UPDATE EC_Orders Failed!'    
            GOTO QUIT    
         END    
      END     
          
      --Insert Receipt Detail        
      INSERT ReceiptDetail (ReceiptKey,ReceiptLineNumber,ExternReceiptKey,ExternLineNo,StorerKey,POKey,Sku,AltSku,Id,Status,DateReceived,QtyExpected  
                        ,QtyAdjusted,QtyReceived,UOM,PackKey,VesselKey,VoyageKey,XdockKey,ContainerKey,ToLoc,ToLot,ToId,ConditionCode,Lottable01  
                        ,Lottable02,Lottable03,Lottable04,Lottable05,CaseCnt,InnerPack,Pallet,[Cube],GrossWgt,NetWgt,OtherUnit1,OtherUnit2,UnitPrice  
                        ,ExtendedPrice,EffectiveDate,AddDate,AddWho,EditDate,EditWho,TrafficCop,ArchiveCop,TariffKey,FreeGoodQtyExpected,FreeGoodQtyReceived  
                        ,SubReasonCode,FinalizeFlag,DuplicateFrom,BeforeReceivedQty,PutawayLoc,ExportStatus,SplitPalletFlag,POLineNumber,LoadKey,ExternPoKey  
                        ,UserDefine01,UserDefine02,UserDefine03,UserDefine04,UserDefine05,UserDefine06,UserDefine07,UserDefine08,UserDefine09,UserDefine10  
                        ,Lottable06,Lottable07,Lottable08,Lottable09,Lottable10,Lottable11,Lottable12,Lottable13,Lottable14,Lottable15)  
      SELECT ReceiptKey,ReceiptLineNumber,ExternReceiptKey,ExternLineNo,StorerKey,POKey,Sku,AltSku,Id,Status,DateReceived,QtyExpected  
                        ,QtyAdjusted,QtyReceived,UOM,PackKey,VesselKey,VoyageKey,XdockKey,ContainerKey,ToLoc,ToLot,ToId,ConditionCode,Lottable01  
                        ,Lottable02,Lottable03,Lottable04,Lottable05,CaseCnt,InnerPack,Pallet,[Cube],GrossWgt,NetWgt,OtherUnit1,OtherUnit2,UnitPrice  
                        ,ExtendedPrice,EffectiveDate,AddDate,AddWho,EditDate,EditWho,TrafficCop,ArchiveCop,TariffKey,FreeGoodQtyExpected,FreeGoodQtyReceived  
                        ,SubReasonCode,FinalizeFlag,DuplicateFrom,BeforeReceivedQty,PutawayLoc,ExportStatus,SplitPalletFlag,POLineNumber,LoadKey,ExternPoKey  
                        ,UserDefine01,UserDefine02,UserDefine03,UserDefine04,UserDefine05,UserDefine06,UserDefine07,UserDefine08,UserDefine09,UserDefine10  
                        ,Lottable06,Lottable07,Lottable08,Lottable09,Lottable10,Lottable11,Lottable12,Lottable13,Lottable14,Lottable15  
      FROM EC_ReceiptDetail   
      WHERE ReceiptKey = @n_ECReceiptKey  
  
      SET @n_Err = @@ERROR    
  
      IF @n_Err <> 0     
      BEGIN    
         SET @n_Continue = 3    
         SET @b_success = 0    
         SET @c_ErrMsg = 'Insert Receipt Failed!'    
         GOTO QUIT    
      END  
   END -- If b_success = 1      
    
QUIT:    
   IF @n_continue = 3  -- Error Occured - Process And Return    
   BEGIN    
      SELECT @b_success = 0    
    
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_starttcnt    
      BEGIN    
         ROLLBACK TRAN    
      END    
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispPostECOrder'    
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR -- SQL 2012 (Jay01)   
      RETURN    
   END    
   ELSE    
   BEGIN    
      WHILE @@TRANCOUNT > @n_starttcnt    
      BEGIN    
         COMMIT TRAN    
      END    
      RETURN    
   END       
    
END -- Procedure     
  

GO