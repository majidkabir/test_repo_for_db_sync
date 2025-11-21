SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: isp_Delivery_Note55                                */  
/* Creation Date: 10-Dec-2021                                           */  
/* Copyright: LFL                                                       */  
/* Written by: CHONGCS                                                  */  
/*                                                                      */  
/* Purpose: WMS-18505 -[CN] DIAGEO_WMS_Delivery Note Carton Report_CR   */
/*                                                                      */  
/*                                                                      */  
/* Called By: r_dw_delivery_note55                                      */  
/*                                                                      */  
/* GitLab Version: 1.0                                                  */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/* 2021-12-10   CHONGCS  1.0  Devops Scripts Combine                    */
/************************************************************************/   

CREATE PROCEDURE [dbo].[isp_Delivery_Note55]
   @c_MBOLKey      NVARCHAR(10)
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @n_Continue      INT = 1,
           @n_StartTCnt     INT,
           @b_success       INT,
           @n_err           INT,
           @c_errmsg        NVARCHAR(255),
           @c_Storerkey     NVARCHAR(15)

   SELECT @n_StartTCnt = @@TRANCOUNT
 
   
   SELECT ORDERS.C_Company,   
         ORDERS.C_Address1,   
         ORDERS.C_Address2,   
         ORDERS.C_Address3,   
         ORDERS.C_Address4,   
         ORDERS.Notes,   
         STORER.Company,   
         ORDERS.AddDate,   
         ORDERS.ExternOrderKey,   
         ORDERS.OrderKey,   
         ORDERS.Door,   
         ORDERS.Route,   
         SKU.DESCR,   
         ORDERDETAIL.QtyPicked,   
         ORDERDETAIL.SKU  ,
			ORDERS.DeliveryNote,
			PACK.CaseCnt,  
         ORDERS.Rdd,  
			STORER.Logo,
			ORDERS.BuyerPO,
         Signatory = CASE WHEN ISNULL(RTRIM(ST.Contact2),'') = '' THEN 'LF Logistics' ELSE ST.Contact2 END
         ,ORDERS.OrderGroup
         ,ORDERS.Notes2
         ,ORDERS.InvoiceNo
         ,ISNULL(MBDET.UserDefine01,'') as MBDETUDF01
         ,ISNULL(MBDET.UserDefine02,'') as MBDETUDF02
         ,ORDERS.ContainerType
         ,CAST(ORDERS.containerqty as NVARCHAR(10)) As containerqty
         ,ISNULL(CL.Short,'N') as 'ShowDeliveryDate'  
         ,ORDERS.DeliveryDate   
         ,ISNULL(C2.Short,'N') as 'ShowSPRemarks' 
         ,MB.BookingReference AS Bkref   --30
         ,MB. VoyageNumber AS VNum       --30
         ,MB.Equipment   AS MBEqu        --10
         ,MB.DRIVERName  AS DriverName   --30        
    FROM MBOL MB WITH (NOLOCK)
    JOIN  ORDERS WITH (nolock) ON ORDERS.mbolkey = MB.MbolKey
    JOIN STORER WITH (nolock)      ON ( ORDERS.StorerKey = STORER.StorerKey )
    JOIN ORDERDETAIL WITH (nolock) ON ( ORDERS.OrderKey = ORDERDETAIL.OrderKey )  
    JOIN SKU         WITH (nolock) ON ( ORDERDETAIL.StorerKey = SKU.StorerKey ) and
												  ( ORDERDETAIL.Sku = SKU.Sku )    
    JOIN PACK        WITH (nolock) ON ( SKU.PackKey = PACK.PackKey ) 
    LEFT JOIN STORER ST WITH (NOLOCK) ON (ST.Storerkey = 'IDS')     
    LEFT JOIN MBOLDETAIL MBDET WITH (NOLOCK) ON MBDET.orderkey = ORDERS.OrderKey 
    LEFT JOIN CODELKUP as CL WITH (NOLOCK) ON CL.ListName = 'REPORTCFG' AND CL.Long = 'r_dw_delivery_note_ctn01'
                                              AND CL.Code = 'ShowDeliveryDate' AND CL.Storerkey = STORER.StorerKey   
   LEFT JOIN CODELKUP as C2 WITH (NOLOCK) ON C2.ListName = 'REPORTCFG' AND C2.Long = 'r_dw_delivery_note_ctn01'
                                              AND C2.Code = 'SHOWSPREMARKS' AND C2.Storerkey = STORER.StorerKey  
   WHERE  ( mb.mbolkey = @c_MBOLKey)
ORDER BY ORDERDETAIL.OrderLineNumber ASC 
   
QUIT_SP:
   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0
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
      execute nsp_logerror @n_err, @c_errmsg, 'isp_Delivery_Note55'
      --RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SET @b_success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END 
   
END -- End Procedure

GO