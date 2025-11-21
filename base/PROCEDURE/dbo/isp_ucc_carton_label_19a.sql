SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_UCC_Carton_Label_19a                           */
/* Creation Date: 03-Jan-2011                                           */
/* Copyright: IDS                                                       */
/* Written by: GTGoh                                                    */
/*                                                                      */
/* Purpose: Adidas UCC Carton Label                                     */
/*                                                                      */
/* Called By: Use in datawindow r_dw_ucc_carton_label_19                */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Purposes                                      */
/* 25Apr2011    GTGOH     Add in PackDetail.Qty and Orders.DeliveryDate */
/*                        (GOH01)                                       */
/* 28-Jan-2019  TLTING_ext 1.1  enlarge externorderkey field length      */
/************************************************************************/

CREATE PROC [dbo].[isp_UCC_Carton_Label_19a] (
       @cStorerKey   NVARCHAR(15), 
       @cDropID    NVARCHAR(18),
       @cStartCarton NVARCHAR(10),  
       @cEndCarton NVARCHAR(10)  
)
AS
BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   

   DECLARE @n_continue    int,
           @c_errmsg      NVARCHAR(255),
           @b_success     int,
           @n_err         int, 
           @b_debug       int
   
   SET @b_debug = 0

   DECLARE @c_PickSlipNo   NVARCHAR(10),
           @n_MinCartonNo  int,
           @n_MaxCartonNo  int,
           @n_Count        int,
           @n_CartonNo     int,
           @c_Orderkey     NVARCHAR(10)
   
   SET @n_MinCartonNo = 0
   SET @n_MaxCartonNo = 0
   SET @n_Count = 0
   SET @n_CartonNo = 0
   SET @c_Orderkey = ''
   
   DECLARE @t_Result Table (
           	DropID         NVARCHAR(18) NULL,
            ExternOrderKey NVARCHAR(50) NULL,  --tlting_ext
            Route          NVARCHAR(10) NULL,
            C_Company      NVARCHAR(45) NULL,
            C_Address1     NVARCHAR(45) NULL,
            C_Address2     NVARCHAR(45) NULL,
            C_Address3     NVARCHAR(45) NULL,
            C_Address4     NVARCHAR(45) NULL,
            C_City         NVARCHAR(45) NULL,
            StorerKey      NVARCHAR(15) NULL,
            Company        NVARCHAR(45) NULL,
            Address1       NVARCHAR(45) NULL,
            Address2       NVARCHAR(45) NULL,
            Address3       NVARCHAR(45) NULL,
            Address4       NVARCHAR(45) NULL,
            City           NVARCHAR(45) NULL,
            Phone1         NVARCHAR(18) NULL,
            Fax1           NVARCHAR(18) NULL,
            CtnCnt1        int NULL,
            CartonNo       int NULL,
            DeliveryDate   datetime NULL,    --GOH01
            Qty            int NULL          --GOH01            
			  )
   
   -- Insert Label Result To Temp Table
   INSERT INTO @t_Result 
   SELECT DISTINCT PACKD.DROPID, --PD.DropID , 
   ORDERS.ExternOrderkey, 
   ORDERS.Route, 
   ORDERS.C_Company, 
   ORDERS.C_Address1, 
   ORDERS.C_Address2, 
   ORDERS.C_Address3,
   ORDERS.C_Address4, 
   ORDERS.C_City, 
   STORER.StorerKey,
   STORER.Company,
   STORER.Address1,
   STORER.Address2,
   STORER.Address3,
   STORER.Address4,
   STORER.City,
   STORER.Phone1,
   STORER.Fax1,
   PACKH.CtnCnt1,
   PACKD.CartonNo,
   ORDERS.DeliveryDate,    --GOH01
   SUM(PACKD.Qty)          --GOH01 
--   FROM PICKDETAIL PD WITH (NOLOCK) 
   FROM PACKDETAIL PACKD WITH (NOLOCK) 
   JOIN PACKHEADER PACKH WITH (NOLOCK) ON (PACKH.PICKSLIPNO = PACKD.PICKSLIPNO)  
   JOIN ORDERS ORDERS WITH (NOLOCK) ON (ORDERS.ORDERKEY = PACKH.ORDERKEY) 
   JOIN STORER STORER WITH (NOLOCK) ON (STORER.STORERKEY = 'adidasDC2') 
   WHERE PACKD.Storerkey = @cStorerKey AND PACKD.DropID = @cDropID 
   --GOH01 Start
   GROUP BY PACKD.DROPID,  
   ORDERS.ExternOrderkey, 
   ORDERS.Route, 
   ORDERS.C_Company, 
   ORDERS.C_Address1, 
   ORDERS.C_Address2, 
   ORDERS.C_Address3,
   ORDERS.C_Address4, 
   ORDERS.C_City, 
   STORER.StorerKey,
   STORER.Company,
   STORER.Address1,
   STORER.Address2,
   STORER.Address3,
   STORER.Address4,
   STORER.City,
   STORER.Phone1,
   STORER.Fax1,
   PACKH.CtnCnt1,
   PACKD.CartonNo,
   ORDERS.DeliveryDate
   --GOH01 End

   IF NOT EXISTS(SELECT 1 FROM @t_Result)
   BEGIN 
   INSERT INTO @t_Result 
   SELECT DISTINCT PACKD.DROPID, --PD.DropID , 
   ORDERS.ExternOrderkey, 
   ORDERS.Route, 
   ORDERS.C_Company, 
   ORDERS.C_Address1, 
   ORDERS.C_Address2, 
   ORDERS.C_Address3,
   ORDERS.C_Address4, 
   ORDERS.C_City, 
   STORER.StorerKey,
   STORER.Company,
   STORER.Address1,
   STORER.Address2,
   STORER.Address3,
   STORER.Address4,
   STORER.City,
   STORER.Phone1,
   STORER.Fax1,
   PACKH.CtnCnt1,
   PACKD.CartonNo, 
   ORDERS.DeliveryDate,    --GOH01
   SUM(PACKD.Qty)          --GOH01 
   FROM PACKHEADER PACKH WITH (NOLOCK)
   JOIN PACKDETAIL PACKD WITH (NOLOCK) ON (PACKD.PICKSLIPNO = PACKH.PICKSLIPNO)  
   JOIN ORDERS ORDERS WITH (NOLOCK) ON (ORDERS.ORDERKEY = PACKH.ORDERKEY) 
   JOIN STORER STORER WITH (NOLOCK) ON (STORER.STORERKEY = 'adidasDC2') 
   WHERE PACKD.Storerkey = @cStorerKey AND PACKH.PICKSLIPNO = @cDropID 
   --GOH01 Start
   GROUP BY PACKD.DROPID,  
   ORDERS.ExternOrderkey, 
   ORDERS.Route, 
   ORDERS.C_Company, 
   ORDERS.C_Address1, 
   ORDERS.C_Address2, 
   ORDERS.C_Address3,
   ORDERS.C_Address4, 
   ORDERS.C_City, 
   STORER.StorerKey,
   STORER.Company,
   STORER.Address1,
   STORER.Address2,
   STORER.Address3,
   STORER.Address4,
   STORER.City,
   STORER.Phone1,
   STORER.Fax1,
   PACKH.CtnCnt1,
   PACKD.CartonNo,
   ORDERS.DeliveryDate
   --GOH01 End
   END
   
   SELECT DISTINCT * FROM @t_Result 
   
END



GO