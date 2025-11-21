SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Stored Procedure: isp_UCC_Carton_Label_104_rdt                       */    
/* Creation Date: 14-Jun-2021                                           */    
/* Copyright: LFL                                                       */    
/* Written by: WLChooi                                                  */    
/*                                                                      */    
/* Purpose: WMS-17265 - Adidas UCC Shipping & Carton Label              */    
/*                                                                      */    
/* Called By: r_dw_ucc_carton_label_104_rdt                             */      
/*                                                                      */    
/* GitLab Version: 1.3                                                  */    
/*                                                                      */    
/* Version: 5.4                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author  Ver   Purposes                                  */ 
/* 2021-06-14  WLChooi  1.0   Created - DevOps Combine Script           */   
/* 2021-11-03  WLChooi  1.1   WMS-17265 - Show/Hide Route and Change Qty*/
/*                            logic (WL01)                              */
/* 2021-11-11  WLChooi  1.2   WMS-17265 - Add CartonType and Userkey    */
/*                            (WL02)                                    */
/* 2022-03-31  WLChooi  1.3   WMS-17265 - Modify Logic for CDD (WL03)   */
/* 2022-04-11  WLChooi  1.4   Bug Fix - Extend VAR Length (WL04)        */
/************************************************************************/    
CREATE PROC [dbo].[isp_UCC_Carton_Label_104_rdt] (    
       @c_Pickslipno   NVARCHAR(10),     
       @c_FromCartonNo NVARCHAR(10),    
       @c_ToCartonNo   NVARCHAR(10),
       @c_FromLabelNo  NVARCHAR(20),
       @c_ToLabelNo    NVARCHAR(20),
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
           @c_UOM          NVARCHAR(10)
       
   SET @n_MinCartonNo = 0    
   SET @n_MaxCartonNo = 0    
   SET @n_Count = 0    

   DECLARE @t_DropID TABLE (  
      LabelNo      NVARCHAR(20)
    , Indicator    NVARCHAR(10)
   )

   DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT PD.LabelNo, PD.StorerKey
   FROM PACKDETAIL PD (NOLOCK)
   WHERE PD.PickSlipNo = @c_Pickslipno
   AND PD.CartonNo BETWEEN CAST(@c_FromCartonNo AS INT) AND CAST(@c_ToCartonNo AS INT) 

   OPEN CUR_LOOP

   FETCH NEXT FROM CUR_LOOP INTO @c_LabelNo, @c_Storerkey

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      IF EXISTS (SELECT 1 FROM PICKDETAIL (NOLOCK) 
                 WHERE DropID = @c_LabelNo 
                 AND Storerkey = @c_Storerkey
                 AND UOM = '2')
      BEGIN
         INSERT INTO @t_DropID (LabelNo, Indicator)
         SELECT @c_LabelNo, 'FC'
      END

      FETCH NEXT FROM CUR_LOOP INTO @c_LabelNo, @c_Storerkey
   END
   CLOSE CUR_LOOP
   DEALLOCATE CUR_LOOP
       
   DECLARE @t_Result Table (    
            DropID         NVARCHAR(20) NULL,    
            Loadkey        NVARCHAR(50) NULL,
            [Route]        NVARCHAR(10) NULL,    
            C_Company      NVARCHAR(100) NULL,   --WL04   
            C_Address1     NVARCHAR(100) NULL,   --WL04   
            C_Address2     NVARCHAR(100) NULL,   --WL04   
            C_Address3     NVARCHAR(100) NULL,   --WL04   
            C_Address4     NVARCHAR(100) NULL,   --WL04   
            C_City         NVARCHAR(100) NULL,   --WL04   
            C_State        NVARCHAR(100) NULL,   --WL04      
            StorerKey      NVARCHAR(15) NULL,    
            Company        NVARCHAR(100) NULL,   --WL04     
            Address1       NVARCHAR(100) NULL,   --WL04     
            Address2       NVARCHAR(100) NULL,   --WL04     
            Address3       NVARCHAR(100) NULL,   --WL04     
            Address4       NVARCHAR(100) NULL,   --WL04     
            City           NVARCHAR(100) NULL,   --WL04     
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
            CartonType     NVARCHAR(50),   --WL02
            Userkey        NVARCHAR(18)    --WL02   
   )    
       
   -- Insert Label Result To Temp Table    
   INSERT INTO @t_Result     
   SELECT DISTINCT PACKD.LabelNo,   
   ORDERS.Loadkey,               
   CASE WHEN ISNULL(CL3.Short,'N') = 'Y' THEN ORDERS.[Route] ELSE '' END AS [Route],   --WL01     
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
              WHERE PH.PickSlipNo = @c_Pickslipno),                                    
   RefNo2 = ISNULL(RTRIM(PACKD.CartonNo),''),                                             
   DeliveryDate = CASE WHEN ORDERS.DocType = 'N' OR ISNULL(ORDERS.Userdefine10, '') = ''   --WL03
                       THEN REPLACE( CONVERT(NVARCHAR(11), ORDERS.DeliveryDate, 106), ' ', '-')  ELSE '' END, 
   UserDefine03 = CASE WHEN ISNULL(ORDERS.UserDefine03, '') <> '' AND ISDATE(ORDERS.UserDefine03) = 1
                       THEN REPLACE( CONVERT(NVARCHAR(11), CAST(ORDERS.UserDefine03 AS DATETIME) , 106), ' ', '-') ELSE '' END, 
   UserDefine10 = CASE WHEN ORDERS.DocType = 'N' AND ISNULL(ORDERS.UserDefine10, '') <> ''  AND ISDATE(ORDERS.UserDefine10) = 1
                       THEN REPLACE( CONVERT(NVARCHAR(11), CAST(ORDERS.UserDefine10 AS DATETIME) , 106), ' ', '-') ELSE '' END,                                         
   Qty = (SELECT SUM(PD.Qty)                                                     
          FROM PACKHEADER PH WITH (NOLOCK)                                   
          JOIN PACKDETAIL PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
          --WHERE PH.Loadkey = ORDERS.Loadkey      --WL01
          WHERE PD.PickSlipNo = PACKD.PickSlipNo   --WL01                                     
          AND   PD.LabelNo = PACKD.LabelNo),                                   
   ORDERS.DocType,
   CASE WHEN ISNULL(CL1.Short,'N') = 'Y' THEN ORDERS.UserDefine04 ELSE '' END AS UserDefine04,
   CASE WHEN ISNULL(CL2.Short,'N') = 'Y' THEN ORDERS.ExternOrderkey ELSE '' END AS ExternOrderkey,
   ISNULL(TDI.Indicator,'') AS FCIndicator,
   CASE WHEN ISNULL(CL1.Short,'N') = 'Y' THEN 'PO No   :' ELSE '' END AS POTitle,
   CASE WHEN ISNULL(CL2.Short,'N') = 'Y' THEN 'DN No   :' ELSE '' END AS DNTitle,
   ISNULL(PIF.CartonType,'') AS CartonType,   --WL02
   TD.UserkeyOverride   --WL02
   FROM PACKDETAIL PACKD WITH (NOLOCK)     
   JOIN PACKHEADER PACKH WITH (NOLOCK) ON (PACKH.PICKSLIPNO = PACKD.PICKSLIPNO)  
   --JOIN LOADPLANDETAIL LPD WITH (NOLOCK) ON (LPD.LoadKey = PACKH.LoadKey)
   JOIN ORDERS ORDERS WITH (NOLOCK) ON (ORDERS.OrderKey = PACKH.OrderKey)          
   LEFT JOIN STORER STORER WITH (NOLOCK) ON (STORER.STORERKEY = 'ADIDAS')  
   LEFT JOIN CODELKUP CL1 WITH (NOLOCK) ON CL1.LISTNAME = 'REPORTCFG' AND CL1.Code = 'ShowPONo' 
                                       AND CL1.Storerkey = ORDERS.StorerKey
                                       AND CL1.Long = 'r_dw_ucc_carton_label_104_rdt'   
   LEFT JOIN CODELKUP CL2 WITH (NOLOCK) ON CL2.LISTNAME = 'REPORTCFG' AND CL2.Code = 'ShowDNNo' 
                                       AND CL2.Storerkey = ORDERS.StorerKey
                                       AND CL2.Long = 'r_dw_ucc_carton_label_104_rdt' 
   LEFT JOIN CODELKUP CL3 WITH (NOLOCK) ON CL3.LISTNAME = 'REPORTCFG' AND CL3.Code = 'ShowRoute'   --WL01
                                       AND CL3.Storerkey = ORDERS.StorerKey                        --WL01
                                       AND CL3.Long = 'r_dw_ucc_carton_label_104_rdt'              --WL01
   LEFT JOIN @t_DropID TDI ON TDI.LabelNo = PACKD.LabelNo  
   LEFT JOIN PACKINFO PIF (NOLOCK) ON PIF.PickSlipNo = PACKD.PickSlipNo   --WL02
                                  AND PIF.CartonNo = PACKD.CartonNo       --WL02
   OUTER APPLY (SELECT TOP 1 ISNULL(TASKDETAIL.UserkeyOverride,'')        --WL02
                AS UserkeyOverride                                        --WL02
                FROM TASKDETAIL (NOLOCK)                                  --WL02
                WHERE TASKDETAIL.Storerkey = PACKH.StorerKey              --WL02
                AND TASKDETAIL.Caseid = PACKD.LabelNo                     --WL02
                AND TASKDETAIL.TaskType = 'CPK') AS TD                    --WL02
   WHERE PACKD.PickSlipNo = @c_Pickslipno 
   --AND PACKD.CartonNo BETWEEN CAST(@c_FromCartonNo AS INT) AND CAST(@c_ToCartonNo AS INT) 
   AND PACKD.LabelNo BETWEEN @c_FromLabelNo AND @c_ToLabelNo
   GROUP BY PACKD.LabelNo,      
   ORDERS.Loadkey, 
   CASE WHEN ISNULL(CL3.Short,'N') = 'Y' THEN ORDERS.[Route] ELSE '' END,   --WL01    
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
   ISNULL(RTRIM(PACKD.CartonNo),''),                     
   ORDERS.DeliveryDate,                                
   CASE WHEN ORDERS.DocType = 'N' OR ISNULL(ORDERS.Userdefine10, '') = ''   --WL03 
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
   PACKD.PickSlipNo,   --WL01
   ISNULL(PIF.CartonType,''),   --WL02
   TD.UserkeyOverride   --WL02
       
   SELECT DISTINCT * FROM @t_Result                      
    
END 

GO