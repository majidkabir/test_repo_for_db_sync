SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

      
/************************************************************************/          
/* Stored Procedure: isp_UCC_Carton_Label_110_rdt                       */          
/* Creation Date: 24-Oct-2021                                           */          
/* Copyright: LFL                                                       */          
/* Written by: Mingle                                                   */          
/*                                                                      */          
/* Purpose: WMS-18187 - SG - Adidas SEA - Shipping and Carton Label     */          
/*                                                                      */          
/* Called By: r_dw_ucc_carton_label_110_rdt                             */            
/*                                                                      */          
/* GitLab Version: 1.0                                                  */          
/*                                                                      */          
/* Version: 5.4                                                         */          
/*                                                                      */        
/* Data Modifications:                                                  */          
/*                                                                      */          
/* Updates:                                                             */          
/* Date         Author  Ver   Purposes                                  */       
/* 2021-10-24   Mingle  1.0   Created - DevOps Combine Script           */         
/************************************************************************/          
CREATE PROC [dbo].[isp_UCC_Carton_Label_110_rdt] (          
       @c_DropID       NVARCHAR(20)      
)          
AS          
BEGIN          
   SET NOCOUNT ON       
   SET ANSI_NULLS OFF       
   SET QUOTED_IDENTIFIER OFF       
   SET CONCAT_NULL_YIELDS_NULL OFF        
             
          
   DECLARE @n_continue    INT,          
           @c_errmsg      NVARCHAR(255),          
           @b_success     INT,          
           @n_err         INT,           
           @b_debug       INT          
             
   SET @b_debug = 0          
          
   DECLARE @n_MinCartonNo  INT,          
           @n_MaxCartonNo  INT,          
           @n_Count        INT,          
           @c_LabelNo      NVARCHAR(20),      
           @c_Storerkey    NVARCHAR(15),      
           @c_UOM          NVARCHAR(10),      
           @c_pickslipno   NVARCHAR(20),      
           @c_SKUGROUP     NVARCHAR(10)      
      
             
   SET @n_MinCartonNo = 0          
   SET @n_MaxCartonNo = 0          
   SET @n_Count = 0          
      
      
   DECLARE @t_DropID TABLE (        
      LabelNo      NVARCHAR(20)      
    , Indicator    NVARCHAR(10)      
    , Pickslipno   NVARCHAR(20)      
    , SKUGROUP     NVARCHAR(10)      
   )      
      
   DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
   SELECT DISTINCT PD.LabelNo, PD.StorerKey,PD.PickSlipNo,S.SKUGROUP      
   FROM PACKHEADER PH WITH (NOLOCK)                                             
   JOIN PACKDETAIL PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)       
   JOIN SKU S WITH (NOLOCK) ON S.StorerKey = PH.StorerKey AND S.Sku = PD.SKU      
   WHERE PD.DropID = @c_DropID AND PD.StorerKey = 'ADIDAS'      
   --AND PD.CartonNo BETWEEN CAST(@c_FromCartonNo AS INT) AND CAST(@c_ToCartonNo AS INT)       
      
   OPEN CUR_LOOP      
      
   FETCH NEXT FROM CUR_LOOP INTO @c_LabelNo, @c_Storerkey,@c_pickslipno,@c_SKUGROUP      
      
   WHILE @@FETCH_STATUS <> -1      
   BEGIN      
      IF EXISTS (SELECT 1 FROM PICKDETAIL (NOLOCK)       
                 WHERE DropID = @c_LabelNo       
                 AND Storerkey = @c_Storerkey      
                 AND UOM = '2'      
                 AND PickSlipNo = @c_pickslipno)      
      BEGIN      
         INSERT INTO @t_DropID (LabelNo, Indicator,Pickslipno)      
         SELECT @c_LabelNo, 'FC',@c_pickslipno      
      END      
      
      FETCH NEXT FROM CUR_LOOP INTO @c_LabelNo, @c_Storerkey,@c_pickslipno,@c_SKUGROUP      
   END      
   CLOSE CUR_LOOP      
   DEALLOCATE CUR_LOOP      
             
   DECLARE @t_Result Table (          
            DropID         NVARCHAR(20) NULL,          
            Loadkey        NVARCHAR(50) NULL,      
            [Route]        NVARCHAR(10) NULL,          
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
            CtnCnt1        INT NULL,          
            CartonNo       INT NULL,            
            DeliveryDate   NVARCHAR(11) NULL,      
            UserDefine03   NVARCHAR(11) NULL,      
            UserDefine10   NVARCHAR(11) NULL,       
            Qty            INT NULL,           
            DocType        NVARCHAR(1) NULL,      
            UserDefine04   NVARCHAR(40),             
            ExternOrderkey NVARCHAR(50),      
            FCIndicator    NVARCHAR(10),      
            POTitle        NVARCHAR(50),      
            DNTitle        NVARCHAR(50),      
            prefix         NVARCHAR(11),      
            LabelNo        NVARCHAR(20) NULL,  
            Status         NVARCHAR(10) NULL    
   )          
             
   -- Insert Label Result To Temp Table          
   INSERT INTO @t_Result             
   --SELECT DISTINCT PACKD.DropID,         
   SELECT DISTINCT DropID = CASE WHEN PACKH.Status <> '9' THEN 'NOT PACKED CONFIRMED' ELSE PACKD.DropID END,   --ML01         
   ORDERS.Loadkey,                     
   --ORDERS.[Route],          
   --CASE WHEN ISNULL(CL4.Short,'N') = 'Y' THEN ORDERS.[Route] ELSE '' END AS [Route],         
   CASE WHEN PACKH.Status <> '9' THEN 'NOTPACK' ELSE CASE WHEN ISNULL(CL4.Short,'N') = 'Y' THEN ORDERS.[Route] ELSE '' END END AS [Route],   --ML01         
   ORDERS.C_Company,           
   ORDERS.C_Address1,           
   ORDERS.C_Address2,           
   ORDERS.C_Address3,          
   ORDERS.C_Address4,           
   ORDERS.C_City,           
   ORDERS.C_State,         
   STORER.StorerKey,          
   ISNULL(STORER.Company,'')  AS Company,          
   ISNULL(STORER.Address1,'') AS Address1,          
   ISNULL(STORER.Address2,'') AS Address2,          
   ISNULL(STORER.Address3,'') AS Address3,          
   ISNULL(STORER.Address4,'') AS Address4,          
   STORER.City,          
   STORER.Phone1,          
   STORER.Fax1,          
   CtnCnt1 = (SELECT COUNT(DISTINCT PD.LabelNo)                                             
              FROM PACKHEADER PH WITH (NOLOCK)                                             
              JOIN PACKDETAIL PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)          
              WHERE PD.PickSlipNo = @c_pickslipno),                                                                                              
   --RefNo2 = CASE WHEN PACKH.Status = '9' THEN 'NOT PACKED CONFIRMED' ELSE ISNULL(RTRIM(PACKD.CartonNo),'') END,   
   --START ML01  
   Cartonno = (Select Count(Distinct PD2.Cartonno) 
   FROM PackDetail PD2 
   WHERE PD2.Cartonno < PACKD.Cartonno + 1 AND PD2.PickSlipNo = @c_pickslipno),
   --END ML01                                                
   DeliveryDate = CASE WHEN ORDERS.DocType = 'E' OR ISNULL(ORDERS.Userdefine10, '') = ''      
                       THEN REPLACE( CONVERT(NVARCHAR(11), ORDERS.DeliveryDate, 106), ' ', '-')  ELSE '' END,       
   UserDefine03 = CASE WHEN ISNULL(ORDERS.UserDefine03, '') <> '' AND ISDATE(ORDERS.UserDefine03) = 1      
                       THEN REPLACE( CONVERT(NVARCHAR(11), CAST(ORDERS.UserDefine03 AS DATETIME) , 106), ' ', '-') ELSE '' END,       
   UserDefine10 = CASE WHEN ORDERS.DocType = 'N' AND ISNULL(ORDERS.UserDefine10, '') <> ''  AND ISDATE(ORDERS.UserDefine10) = 1      
                       THEN REPLACE( CONVERT(NVARCHAR(11), CAST(ORDERS.UserDefine10 AS DATETIME) , 106), ' ', '-') ELSE '' END,                                               
   Qty = (SELECT SUM(PD.Qty)                                                           
          FROM PACKHEADER PH WITH (NOLOCK)                                         
          JOIN PACKDETAIL PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)      
          --WHERE PH.Loadkey = ORDERS.Loadkey      
          WHERE PH.PickSlipNo = PD.PickSlipNo                                       
          AND   PD.LabelNo = PACKD.LabelNo),                                        
   ORDERS.DocType,      
   CASE WHEN ISNULL(CL1.Short,'N') = 'Y' THEN ORDERS.UserDefine04 ELSE '' END AS UserDefine04,      
   CASE WHEN ISNULL(CL2.Short,'N') = 'Y' THEN ORDERS.ExternOrderkey ELSE '' END AS ExternOrderkey,      
   ISNULL(TDI.Indicator,'') AS FCIndicator,      
   CASE WHEN ISNULL(CL1.Short,'N') = 'Y' THEN 'PO No   :' ELSE '' END AS POTitle,      
   CASE WHEN ISNULL(CL2.Short,'N') = 'Y' THEN 'DN No   :' ELSE '' END AS DNTitle,      
   prefix = (SELECT TOP 1 ISNULL(CODELKUP.SHORT,'')      
             FROM CODELKUP(NOLOCK)       
             WHERE CODELKUP.LISTNAME = 'ADIDIVPFIX' AND CODELKUP.STORERKEY = 'adidas' AND CODELKUP.CODE = @c_SKUGROUP),       
   PACKD.LabelNo,   --ML01  
   PACKH.Status   --ML01     
   FROM PACKDETAIL PACKD WITH (NOLOCK)           
   JOIN PACKHEADER PACKH WITH (NOLOCK) ON PACKH.PickSlipNo = PACKD.PickSlipNo        
   --JOIN LOADPLANDETAIL LPD WITH (NOLOCK) ON (LPD.LoadKey = PACKH.LoadKey)      
   JOIN ORDERS ORDERS WITH (NOLOCK) ON (ORDERS.OrderKey = PACKH.OrderKey)      
   JOIN SKU S WITH (NOLOCK) ON S.StorerKey = ORDERS.StorerKey AND S.Sku = PACKD.SKU                
   LEFT JOIN STORER STORER WITH (NOLOCK) ON (STORER.STORERKEY = 'ADIDAS')        
   LEFT JOIN CODELKUP CL1 WITH (NOLOCK) ON CL1.LISTNAME = 'REPORTCFG' AND CL1.Code = 'ShowPONo'       
                                       AND CL1.Storerkey = ORDERS.StorerKey      
                                       AND CL1.Long = 'r_dw_ucc_carton_label_110_rdt'         
   LEFT JOIN CODELKUP CL2 WITH (NOLOCK) ON CL2.LISTNAME = 'REPORTCFG' AND CL2.Code = 'ShowDNNo'       
                                       AND CL2.Storerkey = ORDERS.StorerKey      
                                       AND CL2.Long = 'r_dw_ucc_carton_label_110_rdt'       
   LEFT JOIN @t_DropID TDI ON TDI.LabelNo = PACKD.LabelNo        
   LEFT JOIN CODELKUP CL3 WITH (NOLOCK) ON CL3.LISTNAME = 'ADIDIVPFIX' AND CL3.Code = S.SKUGROUP       
                                       AND CL3.Storerkey = ORDERS.StorerKey      
   LEFT JOIN CODELKUP CL4 WITH (NOLOCK) ON CL4.LISTNAME = 'REPORTCFG' AND CL4.Code = 'ShowRoute'      
                                       AND CL4.Storerkey = ORDERS.StorerKey      
   WHERE PACKD.DropID = @c_DropID AND PACKD.Storerkey = 'ADIDAS'       
   GROUP BY PACKD.DropID,            
   ORDERS.Loadkey,       
   --ORDERS.[Route],         
   CASE WHEN ISNULL(CL4.Short,'N') = 'Y' THEN ORDERS.[Route] ELSE '' END,        
   ORDERS.C_Company,           
   ORDERS.C_Address1,           
   ORDERS.C_Address2,           
   ORDERS.C_Address3,          
   ORDERS.C_Address4,           
   ORDERS.C_City,          
   ORDERS.C_State,          
   STORER.StorerKey,          
   ISNULL(STORER.Company,''),          
   ISNULL(STORER.Address1,''),          
   ISNULL(STORER.Address2,''),          
   ISNULL(STORER.Address3,''),         
   ISNULL(STORER.Address4,''),          
   STORER.City,          
   STORER.Phone1,          
   STORER.Fax1,                           
   --ISNULL(RTRIM(PACKD.CartonNo),''),  
   PACKD.CartonNo,                        
   ORDERS.DeliveryDate,                                      
   CASE WHEN ORDERS.DocType = 'E' OR ISNULL(ORDERS.Userdefine10, '') = ''       
        THEN REPLACE( CONVERT(NVARCHAR(11), ORDERS.DeliveryDate, 106), ' ', '-')  ELSE '' END,         
   CASE WHEN ISNULL(ORDERS.UserDefine03, '') <> ''  AND ISDATE(ORDERS.UserDefine03) = 1      
        THEN REPLACE( CONVERT(NVARCHAR(11), CAST(ORDERS.UserDefine03 AS DATETIME) , 106), ' ', '-') ELSE '' END,      
   CASE WHEN ORDERS.DocType = 'N' AND ISNULL(ORDERS.UserDefine10, '') <> '' AND ISDATE(ORDERS.UserDefine10) = 1       
        THEN REPLACE( CONVERT(NVARCHAR(11), CAST(ORDERS.UserDefine10 AS DATETIME) , 106), ' ', '-') ELSE '' END,       
   ORDERS.DocType,      
   CASE WHEN ISNULL(CL1.Short,'N') = 'Y' THEN ORDERS.UserDefine04 ELSE '' END,      
   CASE WHEN ISNULL(CL2.Short,'N') = 'Y' THEN ORDERS.ExternOrderkey ELSE '' END,      
   ISNULL(TDI.Indicator,''),      
   CASE WHEN ISNULL(CL1.Short,'N') = 'Y' THEN 'PO No   :' ELSE '' END,      
   CASE WHEN ISNULL(CL2.Short,'N') = 'Y' THEN 'DN No   :' ELSE '' END,      
   PACKD.LabelNo,   --ML01        
   PACKH.Status     --ML01       
   SELECT DISTINCT * FROM @t_Result                            
          
END 

GO