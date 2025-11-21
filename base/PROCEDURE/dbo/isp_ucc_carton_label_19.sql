SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Stored Procedure: isp_UCC_Carton_Label_19                            */    
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
/* Date         Author  Ver   Purposes                                  */    
/* 25Apr2011    GTGOH         Add in PackDetail.Qty and                 */    
/*                            Orders.DeliveryDate(GOH01)                */    
/* 14-MAR-2014  YTWan   1.1   SOS#301166 - Change ExternOrderkey to     */    
/*                            Show Loadkey. (Wan01)                     */    
/* 31-MAR-2014  YTWan   1.2   Fixed. Double Qty (Wan02)                 */     
/* 12-Oct-2018  JunYan  1.3   WMS-6411 - Add Priority field, change     */  
/*                            DeliveryDate format and Add UserDefine03  */  
/*                            to DD-MMM-YYYY (CJY01)                    */    
/* 28-Jan-2019  TLTING_ext 1.4  enlarge externorderkey field length     */
/* 20-Sep-2021  Mingle_ 1.5   WMS-18006 Add new mapping(ML01)           */
/************************************************************************/    
    
CREATE PROC [dbo].[isp_UCC_Carton_Label_19] (    
       @cStorerKey   NVARCHAR(15),     
       @cDropID    NVARCHAR(18)    
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
            ExternOrderKey NVARCHAR(50) NULL,     --tlting_ext
            Route          NVARCHAR(10) NULL,    
            C_Company      NVARCHAR(45) NULL,    
            C_Address1     NVARCHAR(45) NULL,    
            C_Address2     NVARCHAR(45) NULL,    
            C_Address3     NVARCHAR(45) NULL,    
            C_Address4     NVARCHAR(45) NULL,    
            C_City         NVARCHAR(45) NULL,    
            C_State        NVARCHAR(45) NULL,       
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
         -- DeliveryDate   datetime NULL,    --GOH01   -- (CJY01)    
            DeliveryDate   NVARCHAR(11) NULL,          -- (CJY01)    
            UserDefine03   NVARCHAR(11) NULL,          -- (CJY01)    
            UserDefine10   NVARCHAR(11) NULL,          -- (CJY01)    
            Qty            int NULL,         --GOH01     
			   DocType        NVARCHAR(1) NULL,           -- (CJY01)  
            PONum          NVARCHAR(100) NULL          --(ML01)
     )    
       
   -- Insert Label Result To Temp Table    
   INSERT INTO @t_Result     
   SELECT DISTINCT PACKD.DROPID,  --PD.DropID ,     
   ORDERS.Loadkey,                --ORDERS.ExternOrderkey, (Wan01)     
   ORDERS.Route,     
   ORDERS.C_Company,     
   ORDERS.C_Address1,     
   ORDERS.C_Address2,     
   ORDERS.C_Address3,    
   ORDERS.C_Address4,     
   ORDERS.C_City,     
   ORDERS.C_State,   
   STORER.StorerKey,    
   STORER.Company,    
   STORER.Address1,    
   STORER.Address2,    
   STORER.Address3,    
   STORER.Address4,    
   STORER.City,    
   STORER.Phone1,    
   STORER.Fax1,    
   --PACKH.CtnCnt1,                                                              --(Wan01)    
   CtnCnt1 = (SELECT COUNT(DISTINCT PD.DropID)                                   --(Wan01)    
              FROM PACKHEADER PH WITH (NOLOCK)                                   --(Wan01)    
              JOIN PACKDETAIL PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)--(Wan01)    
              WHERE PH.Loadkey = ORDERS.Loadkey),                                --(Wan01)    
   --PACKD.CartonNo,                                                             --(Wan01)    
   RefNo2 = ISNULL(RTRIM(PACKD.RefNo2),''),                                      --(Wan01)    
   --ORDERS.DeliveryDate,    --GOH01                                             --(Wan02)    
   --DeliveryDate = CONVERT(NVARCHAR(10),ORDERS.DeliveryDate,112),                 --(Wan02)  -- (CJY01)  
   DeliveryDate = CASE WHEN ORDERS.DocType = 'E' OR ISNULL(ORDERS.Userdefine10, '') = '' 
                       THEN REPLACE( CONVERT(NVARCHAR(11), ORDERS.DeliveryDate, 106), ' ', '-')  ELSE '' END,   -- (CJY01)    
   UserDefine03 = CASE WHEN ISNULL(ORDERS.UserDefine03, '') <> '' AND ISDATE(ORDERS.UserDefine03) = '1'  
                       THEN REPLACE( CONVERT(NVARCHAR(11), CAST(ORDERS.UserDefine03 AS DATETIME) , 106), ' ', '-') ELSE '' END,   -- (CJY01)   
   UserDefine10 = CASE WHEN ORDERS.DocType = 'N' AND ISNULL(ORDERS.UserDefine10, '') <> '' AND ISDATE(ORDERS.UserDefine10) = '1'
                       THEN REPLACE( CONVERT(NVARCHAR(11), CAST(ORDERS.UserDefine10 AS DATETIME) , 106), ' ', '-') ELSE '' END,   -- (CJY01)    
   --SUM(PACKD.Qty)          --GOH01                                             --(Wan02)    
   Qty = (SELECT SUM(PD.Qty)                                                     --(Wan02)    
              FROM PACKHEADER PH WITH (NOLOCK)                                   --(Wan02)    
              JOIN PACKDETAIL PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)--(Wan02)    
              WHERE PH.Loadkey = ORDERS.Loadkey                                  --(Wan02)             
              AND   PD.DropID = PACKD.DropID),                                    --(Wan02)   
   ORDERS.DocType,      -- (CJY01)  
   PONum = CASE WHEN ISNULL(ORDERS.POKEY,'') <> '' AND ISNULL(ORDERS.M_COMPANY,'') <> '' THEN ORDERS.POKEY + '/' + ORDERS.M_COMPANY
           WHEN ISNULL(ORDERS.POKEY,'') <> '' AND ISNULL(ORDERS.M_COMPANY,'') = '' THEN ORDERS.POKEY
           WHEN ISNULL(ORDERS.POKEY,'') = '' AND ISNULL(ORDERS.M_COMPANY,'') <> '' THEN ORDERS.M_COMPANY
           ELSE '' END 
   FROM PACKDETAIL PACKD WITH (NOLOCK)     
   JOIN PACKHEADER PACKH WITH (NOLOCK) ON (PACKH.PICKSLIPNO = PACKD.PICKSLIPNO)      
--   JOIN ORDERS ORDERS WITH (NOLOCK) ON (ORDERS.ORDERKEY = PACKH.ORDERKEY)      --(Wan01)    
   JOIN ORDERS ORDERS WITH (NOLOCK) ON (ORDERS.Loadkey = PACKH.Loadkey)          --(Wan01)    
   JOIN STORER STORER WITH (NOLOCK) ON (STORER.STORERKEY = 'adidasDC2')     
   WHERE PACKD.Storerkey = @cStorerKey AND PACKD.DropID = @cDropID     
   --GOH01 Start    
   GROUP BY PACKD.DROPID,      
   ORDERS.Loadkey,               --ORDERS.ExternOrderkey,   (Wan01)    
   ORDERS.Route,     
   ORDERS.C_Company,     
   ORDERS.C_Address1,     
   ORDERS.C_Address2,     
   ORDERS.C_Address3,    
   ORDERS.C_Address4,     
   ORDERS.C_City,    
   ORDERS.C_State,    
   STORER.StorerKey,    
   STORER.Company,    
   STORER.Address1,    
   STORER.Address2,    
   STORER.Address3,    
   STORER.Address4,    
   STORER.City,    
   STORER.Phone1,    
   STORER.Fax1,    
   --PACKH.CtnCnt1,                                         --(Wan01)    
   --PACKD.CartonNo,                                        --(Wan01)    
   ISNULL(RTRIM(PACKD.RefNo2),''),                          --(Wan01)    
   ORDERS.DeliveryDate,                                    --(Wan02)    
   --CONVERT(NVARCHAR(10),ORDERS.DeliveryDate,112)            --(Wan02)  -- (CJY01)   
	CASE WHEN ORDERS.DocType = 'E' OR ISNULL(ORDERS.Userdefine10, '') = '' 
         THEN REPLACE( CONVERT(NVARCHAR(11), ORDERS.DeliveryDate, 106), ' ', '-')  ELSE '' END,   -- (CJY01)    
    CASE WHEN ISNULL(ORDERS.UserDefine03, '') <> '' AND ISDATE(ORDERS.UserDefine03) = '1'   
          THEN REPLACE( CONVERT(NVARCHAR(11), CAST(ORDERS.UserDefine03 AS DATETIME) , 106), ' ', '-') ELSE '' END,   -- (CJY01)   
    CASE WHEN ORDERS.DocType = 'N' AND ISNULL(ORDERS.UserDefine10, '') <> '' AND ISDATE(ORDERS.UserDefine10) = '1'
         THEN REPLACE( CONVERT(NVARCHAR(11), CAST(ORDERS.UserDefine10 AS DATETIME) , 106), ' ', '-') ELSE '' END,   -- (CJY01)  
  ORDERS.DocType,      -- (CJY01)  
--GOH01 End 
   CASE WHEN ISNULL(ORDERS.POKEY,'') <> '' AND ISNULL(ORDERS.M_COMPANY,'') <> '' THEN ORDERS.POKEY + '/' + ORDERS.M_COMPANY
        WHEN ISNULL(ORDERS.POKEY,'') <> '' AND ISNULL(ORDERS.M_COMPANY,'') = '' THEN ORDERS.POKEY
        WHEN ISNULL(ORDERS.POKEY,'') = '' AND ISNULL(ORDERS.M_COMPANY,'') <> '' THEN ORDERS.M_COMPANY
        ELSE '' END   
  
   IF NOT EXISTS(SELECT 1 FROM @t_Result)    
   BEGIN     
   INSERT INTO @t_Result     
   SELECT DISTINCT PACKD.DROPID,  --PD.DropID ,     
   ORDERS.Loadkey,               --ORDERS.ExternOrderkey,   (Wan01)    
   ORDERS.Route,     
   ORDERS.C_Company,     
   ORDERS.C_Address1,     
   ORDERS.C_Address2,     
   ORDERS.C_Address3,    
   ORDERS.C_Address4,     
   ORDERS.C_City,   
   ORDERS.C_State,    
   STORER.StorerKey,    
   STORER.Company,    
   STORER.Address1,    
   STORER.Address2,    
   STORER.Address3,    
   STORER.Address4,    
   STORER.City,    
   STORER.Phone1,    
   STORER.Fax1,    
   --PACKH.CtnCnt1,                                                              --(Wan01)    
   CtnCnt1 = (SELECT COUNT(DISTINCT PD.DropID)                                   --(Wan01)    
              FROM PACKHEADER PH WITH (NOLOCK)                                   --(Wan01)    
              JOIN PACKDETAIL PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)--(Wan01)    
              WHERE PH.Loadkey = ORDERS.Loadkey),                                --(Wan01)    
   --PACKD.CartonNo,                                                             --(Wan01)    
   RefNo2 = ISNULL(RTRIM(PACKD.RefNo2),''),                                      --(Wan01)    
 -- ORDERS.DeliveryDate,    --GOH01                                             --(Wan02)    
 --DeliveryDate = CONVERT(NVARCHAR(10),ORDERS.DeliveryDate,112),                 --(Wan02)  -- (CJY01)  
   DeliveryDate = CASE WHEN ORDERS.DocType = 'E' OR ISNULL(ORDERS.Userdefine10, '') = '' 
                       THEN REPLACE( CONVERT(NVARCHAR(11), ORDERS.DeliveryDate, 106), ' ', '-')  ELSE '' END,   -- (CJY01)    
   UserDefine03 = CASE WHEN ISNULL(ORDERS.UserDefine03, '') <> '' AND ISDATE(ORDERS.UserDefine03) = '1'   
                       THEN REPLACE( CONVERT(NVARCHAR(11), CAST(ORDERS.UserDefine03 AS DATETIME) , 106), ' ', '-') ELSE '' END,   -- (CJY01)   
   UserDefine10 = CASE WHEN ORDERS.DocType = 'N' AND ISNULL(ORDERS.UserDefine10, '') <> '' AND ISDATE(ORDERS.UserDefine10) = '1' 
                       THEN REPLACE( CONVERT(NVARCHAR(11), CAST(ORDERS.UserDefine10 AS DATETIME) , 106), ' ', '-') ELSE '' END,   -- (CJY01)   
   --Sum(PACKD.Qty)          --GOH01    
   Qty = (SELECT SUM(PD.Qty)                                                     --(Wan02)    
              FROM PACKHEADER PH WITH (NOLOCK)                                   --(Wan02)    
              JOIN PACKDETAIL PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)--(Wan02)    
              WHERE PH.Loadkey = ORDERS.Loadkey                                  --(Wan02)             
              AND   PD.DropID = PACKD.DropID),                                   --(Wan02) 
   ORDERS.DocType,      -- (CJY01) 
   PONum = CASE WHEN ISNULL(ORDERS.POKEY,'') <> '' AND ISNULL(ORDERS.M_COMPANY,'') <> '' THEN ORDERS.POKEY + '/' + ORDERS.M_COMPANY
           WHEN ISNULL(ORDERS.POKEY,'') <> '' AND ISNULL(ORDERS.M_COMPANY,'') = '' THEN ORDERS.POKEY
           WHEN ISNULL(ORDERS.POKEY,'') = '' AND ISNULL(ORDERS.M_COMPANY,'') <> '' THEN ORDERS.M_COMPANY
           ELSE '' END   
   FROM PACKHEADER PACKH WITH (NOLOCK)    
   JOIN PACKDETAIL PACKD WITH (NOLOCK) ON (PACKD.PICKSLIPNO = PACKH.PICKSLIPNO)      
--   JOIN ORDERS ORDERS WITH (NOLOCK) ON (ORDERS.ORDERKEY = PACKH.ORDERKEY)      --(Wan01)    
   JOIN ORDERS ORDERS WITH (NOLOCK) ON (ORDERS.Loadkey = PACKH.Loadkey)          --(Wan01)    
   JOIN STORER STORER WITH (NOLOCK) ON (STORER.STORERKEY = 'adidasDC2')     
   WHERE PACKD.Storerkey = @cStorerKey AND PACKH.PICKSLIPNO = @cDropID     
   --GOH01 Start    
   GROUP BY PACKD.DROPID,      
   ORDERS.Loadkey,               --ORDERS.ExternOrderkey,   (Wan01)    
   ORDERS.Route,     
   ORDERS.C_Company,     
   ORDERS.C_Address1,     
   ORDERS.C_Address2,     
   ORDERS.C_Address3,    
   ORDERS.C_Address4,     
   ORDERS.C_City,  
   ORDERS.C_State,      
   STORER.StorerKey,    
   STORER.Company,    
   STORER.Address1,    
   STORER.Address2,    
   STORER.Address3,    
   STORER.Address4,    
   STORER.City,    
   STORER.Phone1,    
   STORER.Fax1,    
   --PACKH.CtnCnt1,                                         --(Wan01)    
   --PACKD.CartonNo,                                        --(Wan01)    
   ISNULL(RTRIM(PACKD.RefNo2),''),                          --(Wan01)    
   PACKD.CartonNo,    
 --  ORDERS.DeliveryDate,                                    --(Wan02)    
   --CONVERT(NVARCHAR(10),ORDERS.DeliveryDate,112)            --(Wan02)  -- (CJY01)   
	CASE WHEN ORDERS.DocType = 'E' OR ISNULL(ORDERS.Userdefine10, '') = '' 
         THEN REPLACE( CONVERT(NVARCHAR(11), ORDERS.DeliveryDate, 106), ' ', '-')  ELSE '' END,   -- (CJY01)    
    CASE WHEN ISNULL(ORDERS.UserDefine03, '') <> '' AND ISDATE(ORDERS.UserDefine03) = '1'   
          THEN REPLACE( CONVERT(NVARCHAR(11), CAST(ORDERS.UserDefine03 AS DATETIME) , 106), ' ', '-') ELSE '' END,   -- (CJY01)   
    CASE WHEN ORDERS.DocType = 'N' AND ISNULL(ORDERS.UserDefine10, '') <> '' AND ISDATE(ORDERS.UserDefine10) = '1' 
         THEN REPLACE( CONVERT(NVARCHAR(11), CAST(ORDERS.UserDefine10 AS DATETIME) , 106), ' ', '-') ELSE '' END,   -- (CJY01)  
  ORDERS.DocType,      -- (CJY01)   
--GOH01 End 
   CASE WHEN ISNULL(ORDERS.POKEY,'') <> '' AND ISNULL(ORDERS.M_COMPANY,'') <> '' THEN ORDERS.POKEY + '/' + ORDERS.M_COMPANY
        WHEN ISNULL(ORDERS.POKEY,'') <> '' AND ISNULL(ORDERS.M_COMPANY,'') = '' THEN ORDERS.POKEY
        WHEN ISNULL(ORDERS.POKEY,'') = '' AND ISNULL(ORDERS.M_COMPANY,'') <> '' THEN ORDERS.M_COMPANY
        ELSE '' END   
   END    
       
   SELECT DISTINCT * FROM @t_Result                            
    
END 

GO