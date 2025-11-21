SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  isp_Receipt_Report_01                              */
/* Creation Date: 2021-01-18                                            */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-16006 - [PH] - Adidas Ecom - ASN Receipt_Returns        */
/*                                                                      */
/* Input Parameters:  @c_mbolkey  - MBOL Key                            */
/*                                                                      */
/* Output Parameters:  None                                             */
/*                                                                      */
/* Return Status:  None                                                 */
/*                                                                      */
/* Usage:  Used for report dw = r_receipt_report_01                     */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By:  RMC from MBOL. ReportType = PRNTASN                      */
/*                                                                      */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/************************************************************************/

CREATE PROC [dbo].[isp_Receipt_Report_01] (@c_Receiptkey NVARCHAR(10), @c_Storerkey NVARCHAR(15)) 
AS
BEGIN
   SET NOCOUNT ON         
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue        INT,
           @c_errmsg          NVARCHAR(255),
           @b_success         INT,
           @n_err             INT,
           @n_cnt             INT,
           @c_OtherReference  NVARCHAR(30),
           @c_facility        NVARCHAR(5),
           @c_keyname         NVARCHAR(30),
           @c_printflag       NVARCHAR(1)
           
   SELECT @n_continue = 1, @n_err = 0, @c_errmsg = '', @b_success = 1, @n_cnt = 0
            
   IF @n_continue = 1 OR @n_continue = 2                               
   BEGIN
      SELECT ISNULL(R.SellerCompany,'')    AS SellerCompany
            ,ISNULL(R.CarrierAddress1,'') + ' ' + ISNULL(R.CarrierAddress2,'') + ' ' + ISNULL(R.CarrierCity,'') AS CarrierCity
            ,ISNULL(R.CarrierReference,'') AS CarrierReference
            ,ISNULL(RD.ContainerKey,'')    AS ContainerKey
            ,R.ReceiptKey
            ,R.ReceiptDate
            ,R.ExternReceiptKey
            ,R.WarehouseReference
            ,R.StorerKey
            ,ISNULL(R.Signatory,'') AS Signatory
            ,ISNULL(R.Notes,'') AS Notes
            ,R.ASNReason
            ,RD.ReceiptLineNumber
            ,RD.SKU
            ,S.DESCR
            ,SUM(RD.QtyExpected) AS QtyExpected
            ,SUM(RD.QtyReceived) AS QtyReceived
            ,RD.UOM
            ,R.[Status]
            ,ISNULL(ST.Company,'')      AS Company
            ,ISNULL(ST.Address1,'')     AS Address1
            ,ISNULL(ST.Address2,'')     AS Address2
            ,ISNULL(ST.City,'')         AS City
            ,ISNULL(ST.Zip,'')          AS Zip
            ,ISNULL(ST.Country,'')      AS Country
            ,ISNULL(ST.VAT,'')          AS VAT
            ,ISNULL(ST.[State],'')      AS [State]
            ,ISNULL(ST.ISOCntryCode,'') AS ISOCntryCode
      FROM RECEIPT R (NOLOCK)
      JOIN RECEIPTDETAIL RD (NOLOCK) ON RD.Receiptkey = R.ReceiptKey
      JOIN SKU S (NOLOCK) ON S.StorerKey = RD.Storerkey AND S.SKU = RD.SKU
      JOIN STORER ST (NOLOCK) ON ST.StorerKey = R.StorerKey
      WHERE R.StorerKey = @c_Storerkey AND R.ReceiptKey = @c_Receiptkey
      GROUP BY ISNULL(R.SellerCompany,'')   
              ,ISNULL(R.CarrierAddress1,'') + ' ' + ISNULL(R.CarrierAddress2,'') + ' ' + ISNULL(R.CarrierCity,'')   
              ,ISNULL(R.CarrierReference,'')
              ,ISNULL(RD.ContainerKey,'')   
              ,R.ReceiptKey
              ,R.ReceiptDate
              ,R.ExternReceiptKey
              ,R.WarehouseReference
              ,R.StorerKey
              ,ISNULL(R.Signatory,'')
              ,ISNULL(R.Notes,'')
              ,R.ASNReason
              ,RD.ReceiptLineNumber
              ,RD.SKU
              ,S.DESCR
              ,RD.UOM
              ,R.[Status]
              ,ISNULL(ST.Company,'')     
              ,ISNULL(ST.Address1,'')    
              ,ISNULL(ST.Address2,'')    
              ,ISNULL(ST.City,'')        
              ,ISNULL(ST.Zip,'')         
              ,ISNULL(ST.Country,'')     
              ,ISNULL(ST.VAT,'')         
              ,ISNULL(ST.[State],'')     
              ,ISNULL(ST.ISOCntryCode,'')
   END
            
END                                       

GO