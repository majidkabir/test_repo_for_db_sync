SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/          
/* Stored Procedure: isp_RPT_ASN_RCPDETMTX_002                          */          
/* Creation Date: 3-JUNE-2022                                           */      
/* Copyright: LF Logistics                                              */      
/* Written by: WZPang                                                   */      
/*                                                                      */      
/* Purpose: Convert to Logi Report - r_dw_receiving_matrix_us03  (TH)   */        
/*                                                                      */          
/* Called By: RPT_ASN_RCPDETMTX_002													*/          
/*                                                                      */          
/* PVCS Version: 1.0                                                    */          
/*                                                                      */          
/* Version: 7.0                                                         */          
/*                                                                      */          
/* Data Modifications:                                                  */          
/*                                                                      */          
/* Updates:                                                             */          
/* Date         Author   Ver  Purposes                                  */  
/* 18-June-2022  WZPang   1.0  DevOps Combine Script                    */   
/* 23-Aug-2022   Mingle   1.1  Add new mappings(ML01)                   */ 
/************************************************************************/          
CREATE PROC [dbo].[isp_RPT_ASN_RCPDETMTX_002] (  
      @c_receiptkey      NVARCHAR(10)          
)          
 AS          
 BEGIN          
              
   SET NOCOUNT ON          
   SET ANSI_NULLS ON          
   SET QUOTED_IDENTIFIER OFF          
   SET CONCAT_NULL_YIELDS_NULL OFF          
   SET ANSI_WARNINGS ON          
          
      DECLARE @n_IsRDT     INT    
         , @n_StartTCnt INT    
    
   SET @n_IsRDT     = 0    
   SET @n_StartTCnt = @@TRANCOUNT    
    
   WHILE @@TRANCOUNT > 0     
   BEGIN    
      COMMIT TRAN    
   END    
    
 SELECT Receipt.Receiptkey,     
  Receipt.storerkey,     
  Receipt.rectype,       
  Receipt.carriername,       
  Receipt.userdefine01,       
  Receipt.containerkey ,     
  RD.externReceiptkey,      
  Receipt.addwho,     
  Receipt.adddate,     
  RD.pokey,     
  NOTEs=CONVERT(NVARCHAR(250), Receipt.notes),     
  Receipt.NoOfMasterCtn,    
  Storer.Company,     
  SKU.style,     
  SKU.color,     
  RD.lottable02,      
  SKU.itemclass,     
  QtyExpected = SUM ( ISNULL(RD.QtyExpected, 0)),     
  QtyReceived = SUM( ISNULL(RD.QtyReceived, 0)),     
  Userid = SUSER_SNAME(),     
  Receipt_TYPE = CLK.Description,    
  Receipt.Status,    
  BefoRereceivedQty = SUM( ISNULL(RD.BefoRereceivedQty, 0)),     
  Receipt.facility,     
  Facility_descr = Facility.descr,     
  Facility_UserDefine01 = Facility.UserDefine01,     
  Facility_UserDefine03 = Facility.UserDefine03,     
  Facility_Userdefine04 = Facility.Userdefine04,    
  scanqty = SUM(CASE WHEN RD.QtyReceived > 0 THEN RD.QtyReceived ELSE ISNULL(RD.BeforeReceivedQty,0) END),    
  Receipt.userdefine02,     
  Receipt.userdefine03,     
  Receipt.userdefine04,     
  Receipt.userdefine05,    
  ASNReason = Receipt.ASNReason + '-' + ISNULL(CLK1.Description,''),    
  WHREF = ISNULL(receipt.WarehouseReference,''),
  Receipt.trackingno,	--ML01
  RI.EcomOrderId	--ML01
FROM Receipt WITH (NOLOCK)     
  JOIN ReceiptDetail RD WITH (NOLOCK) ON ( RD.StorerKey = Receipt.StorerKey AND RD.ReceiptKey = Receipt.ReceiptKey ) 
  JOIN ReceiptInfo RI WITH (NOLOCK) ON RI.ReceiptKey = RECEIPT.ReceiptKey	--ML01
  LEFT JOIN SKU WITH (NOLOCK) ON ( SKU.StorerKey = RD.StorerKey AND SKU.SKU = RD.SKU )     
  LEFT JOIN STORER WITH (NOLOCK) ON ( Storer.StorerKey =  Receipt.StorerKey )     
      LEFT OUTER JOIN CODELKUP CLK WITH (NOLOCK) ON (CLK.Code = RECEIPT.RecType AND CLK.Listname = 'RECTYPE' AND CLK.Storerkey =     
  CASE WHEN Receipt.StorerKey NOT IN (SELECT STORERKEY FROM CODELKUP(NOLOCK) WHERE listname='RECTYPE' AND Code= RECEIPT.RecType )     
  THEN '' ELSE Receipt.StorerKey END)    
  JOIN facility WITH (NOLOCK) ON ( facility.facility =  Receipt.facility )          LEFT OUTER JOIN CODELKUP CLK1 WITH (NOLOCK) ON CLK1.LISTNAME ='RETREASON' AND CLK1.Storerkey = Receipt.StorerKey AND CLK1.code=Receipt.ASNReason    
WHERE  ( Receipt.ReceiptKey = @c_receiptkey )     
Group By Receipt.Receiptkey,     
  Receipt.storerkey,     
  Receipt.rectype,       
  Receipt.carriername,       
  Receipt.userdefine01,       
  Receipt.containerkey ,     
  RD.externReceiptkey,      
  Receipt.addwho,     
  Receipt.adddate,     
  RD.pokey,     
  Convert(nvarchar(250), Receipt.notes),     
  Receipt.NoOfMasterCtn,    
  Storer.Company,     
  SKU.style,     
  SKU.color,     
  RD.lottable02,      
  SKU.itemclass,     
  CLK.Description,     
  Receipt.Status,    
  Receipt.facility,     
  Facility.descr,     
  Facility.UserDefine01,     
  Facility.UserDefine03,     
  Facility.Userdefine04,    
  Receipt.userdefine02,     
  Receipt.userdefine03,     
  Receipt.userdefine04,     
  Receipt.userdefine05,    
  Receipt.ASNReason + '-' + ISNULL(CLK1.Description,''),    
  ISNULL(receipt.WarehouseReference,''),
  Receipt.trackingno,	--ML01
  RI.EcomOrderId	--ML01
    
    
   WHILE @@TRANCOUNT < @n_StartTCnt    
   BEGIN    
      BEGIN TRAN    
   END    
END -- procedure 

GO