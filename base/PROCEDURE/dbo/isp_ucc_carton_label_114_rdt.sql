SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Stored Procedure: isp_UCC_Carton_Label_114_rdt                       */
/* Creation Date: 05-Apr-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: CHONGCS                                                  */
/*                                                                      */
/* Purpose: WMS-19296 - [RG] adidas û Carton Label                      */
/*                                                                      */
/* Called By: r_dw_UCC_Carton_Label_114_rdt                             */
/*                                                                      */
/* GitLab Version: 1.2                                                  */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver   Purposes                                  */
/* 2022-04-05  CHONGCS  1.0   Created - DevOps Combine Script           */
/* 2022-07-22  CSCHONG  1.1   WMS-20263 add report config  (CS02)       */
/************************************************************************/
CREATE PROC [dbo].[isp_UCC_Carton_Label_114_rdt] (
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
           @b_debug       INT,
           @c_packstatus  NVARCHAR(10) = '0',
           @n_Maxline     INT,
           @c_LabelNo      NVARCHAR(20),
           @c_Storerkey    NVARCHAR(15),
           @c_UOM          NVARCHAR(10)

   SET @b_debug = 0
   SET @n_Maxline = 9

  SELECT @c_packstatus = PH.Status
  FROM PACKHEADER PH WITH (NOLOCK) 
  WHERE PH.PickSlipNo = @c_Pickslipno


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

   SELECT Loadkey        = PACKHEADER.Loadkey
         ,ExternOrderkey = ISNULL(RTRIM(ORDERS.ExternOrderkey),'')
         ,CtnCnt1        = (SELECT COUNT(DISTINCT PD.LabelNo)
                            FROM PACKHEADER PH WITH (NOLOCK)
                            JOIN PACKDETAIL PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
                            WHERE PH.PickSlipNo = @c_Pickslipno)
         ,Cartonno = (Select Count(Distinct PD2.Cartonno) 
                      FROM PackDetail PD2 
                      WHERE PD2.Cartonno < PACKDETAIL.Cartonno + 1 AND PD2.PickSlipNo = @c_pickslipno)
         ,DropID         = ISNULL(RTRIM(PACKDETAIL.LabelNo),'')
         ,Style          = ISNULL(RTRIM(SKU.Style),'')
         ,Storerkey      = ISNULL(ORDERS.storerkey,'')
        -- ,SkuDesc        = ''--ISNULL(RTRIM(SKU.Descr),'')
         ,SizeQty        = SUM(PACKDETAIL.Qty)
         ,OHRoute        = CASE WHEN ISNULL(CL3.short,'') <> 'N' THEN ISNULL(ORDERS.ROUTE,'') ELSE '' END     --CS02
         ,Consigneekey   = ISNULL(ORDERS.consigneekey,'') 
         ,Facility       = ISNULL(ORDERS.facility,'') 
         --,ShowLargeFont  = ISNULL(CL.SHORT,'N')
         --,ShowSONo       = ISNULL(CL1.SHORT,'N')
         ,M_VAT          = ISNULL(ORDERS.M_VAT,'')  
         ,ST_Address1    = ISNULL(ORDERS.c_address1,'')
         ,ST_Address2    = ISNULL(ORDERS.c_address2,'')
         ,ST_Address3    = ISNULL(ORDERS.c_address3,'')
         ,ST_City        = ISNULL(ORDERS.c_city,'')
         ,ST_State       = ISNULL(ORDERS.c_state,'')
         ,ST_Zip         = ISNULL(ORDERS.c_zip,'') 
         , ROW_NUMBER() OVER ( PARTITION BY ISNULL(RTRIM(ORDERS.ExternOrderkey),''),PACKDETAIL.CartonNo
                           ORDER BY ISNULL(RTRIM(ORDERS.ExternOrderkey),''),PACKDETAIL.cartonno ,ISNULL(RTRIM(SKU.Style),'') )/@n_Maxline + 1  as recgrp
         ,CartonType     = ISNULL(PIF.CartonType,'')   
         ,UserkeyOverride= TD.UserkeyOverride   
         ,BuyerPO        = ISNULL(ORDERS.BuyerPO,'')  
         ,ST_Company     = ISNULL(ORDERS.c_Company,'') 
         ,ODD            = CASE WHEN ISDATE(ORDERS.userdefine03) = 1 THEN REPLACE(CONVERT(NVARCHAR(12),CAST(ORDERS.userdefine03 AS DATETIME),106),' ','-') ELSE '' END
         ,DELDate        = REPLACE(CONVERT(NVARCHAR(12),ORDERS.DeliveryDate,106),' ','-')
         ,oad            = CASE WHEN ISDATE(ORDERS.userdefine10) = 1 THEN REPLACE(CONVERT(NVARCHAR(12),CAST(ORDERS.userdefine10 AS DATETIME),106),' ','-') ELSE '' END
         ,ODUDF02        = ODET.ODUDF02--ISNULL(OD.userdefine02,'')
         ,OHUDF04        = ISNULL(ORDERS.userdefine04,'')   
         ,Prefix         = ISNULL(PF.Dvprefix,'')
         ,FCIndicator    = ISNULL(TDI.Indicator,'')
   FROM PACKHEADER WITH (NOLOCK)
   JOIN PACKDETAIL WITH (NOLOCK) ON (PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo)
   JOIN SKU WITH (NOLOCK) ON (PACKDETAIL.Storerkey = SKU.Storerkey)
                         AND (PACKDETAIL.Sku = SKU.Sku)
   JOIN ORDERS WITH (NOLOCK) ON (PACKHEADER.Orderkey = ORDERS.Orderkey)
   --JOIN ORDERDETAIL OD WITH (NOLOCK) ON OD.Orderkey = ORDERS.Orderkey 
   OUTER APPLY (SELECT TOP 1 ISNULL(OD.userdefine02,'') AS ODUDF02 
                 FROM ORDERDETAIL OD (NOLOCK) WHERE OD.ORDERKEY = ORDERS.ORDERKEY) ODET
   --LEFT JOIN CODELKUP CL WITH (NOLOCK) ON (CL.LISTNAME = 'REPORTCFG' AND CL.CODE = 'ShowPONo' )
   --                                   AND (CL.LONG = 'r_dw_carton_manifest_label_39_rdt' AND CL.STORERKEY = ORDERS.Storerkey)
   --LEFT JOIN CODELKUP CL1 WITH (NOLOCK) ON (CL1.LISTNAME = 'REPORTCFG' AND CL1.CODE = 'ShowDNNo' )
   --                                    AND (CL1.LONG = 'r_dw_carton_manifest_label_39_rdt' AND CL1.STORERKEY = ORDERS.Storerkey)
   --LEFT JOIN CODELKUP CL2 WITH (NOLOCK) ON (CL2.LISTNAME = 'REPORTCFG' AND CL2.CODE = 'ShowSONo' )
   --                                    AND (CL2.LONG = 'r_dw_carton_manifest_label_39_rdt' AND CL2.STORERKEY = ORDERS.Storerkey)
   LEFT JOIN CODELKUP CL3 WITH (NOLOCK) ON (CL3.LISTNAME = 'REPORTCFG' AND CL3.CODE = 'ShowRoute' )                                           --CS02
                                       AND (CL3.LONG = 'r_dw_UCC_Carton_Label_114_rdt' AND CL3.STORERKEY = ORDERS.Storerkey)
   LEFT JOIN PACKINFO PIF (NOLOCK) ON PIF.PickSlipNo = PACKDETAIL.PickSlipNo    
                                  AND PIF.CartonNo = PACKDETAIL.CartonNo        
   OUTER APPLY (SELECT TOP 1 ISNULL(TASKDETAIL.UserkeyOverride,'')              
                AS UserkeyOverride                                              
                FROM TASKDETAIL (NOLOCK)                                        
                WHERE TASKDETAIL.Storerkey = PACKHEADER.StorerKey               
                AND TASKDETAIL.Caseid = PACKDETAIL.LabelNo                      
                AND TASKDETAIL.TaskType = 'CPK') AS TD  
   OUTER APPLY (SELECT TOP 1 ISNULL(CODELKUP.SHORT,'') AS Dvprefix
                FROM dbo.CODELKUP WITH (NOLOCK)
                WHERE CODELKUP.LISTNAME = 'ADIDIVPFIX' 
                AND CODELKUP.STORERKEY = PACKHEADER.Storerkey 
               AND CODELKUP.Code = Sku.SkuGroup 
               AND Sku.Sku = PACKDETAIL.Sku) AS PF    
   LEFT JOIN @t_DropID TDI ON TDI.LabelNo = PACKDETAIL.LabelNo                        
   WHERE PACKHEADER.PickSlipNo = @c_Pickslipno
   --AND PACKD.CartonNo BETWEEN CAST(@c_FromCartonNo AS INT) AND CAST(@c_ToCartonNo AS INT)
   AND PACKDETAIL.LabelNo BETWEEN @c_FromLabelNo AND @c_ToLabelNo
   GROUP BY PACKHEADER.Loadkey
         ,  ISNULL(RTRIM(ORDERS.ExternOrderkey),'')
         ,  ISNULL(RTRIM(PACKDETAIL.CartonNo),'')
         ,  ISNULL(RTRIM(PACKDETAIL.LabelNo),'')
         ,  ISNULL(RTRIM(SKU.Style),'')
         --,  ISNULL(RTRIM(SKU.Descr),'')
         --,  ISNULL(CL.SHORT,'N')
         --,  ISNULL(CL1.SHORT,'N')
         ,  ISNULL(PIF.CartonType,'')    
         ,  ISNULL(ORDERS.M_VAT,'')  
         ,  TD.UserkeyOverride           
         ,  ISNULL(ORDERS.BuyerPO,'')   
         ,  ISNULL(PF.Dvprefix,'')
         ,  PACKDETAIL.Cartonno  
         ,  ISNULL(ORDERS.storerkey,'')
         ,  CASE WHEN ISNULL(CL3.short,'') <> 'N' THEN ISNULL(ORDERS.ROUTE,'') ELSE '' END     --CS02
         ,  ISNULL(ORDERS.consigneekey,'')      
         ,  ISNULL(ORDERS.facility,'')
         ,  ISNULL(ORDERS.c_Company,'') 
         ,  ISNULL(ORDERS.c_address1,'')
         ,  ISNULL(ORDERS.c_address2,'')
         ,  ISNULL(ORDERS.c_address3,'')
         ,  ISNULL(ORDERS.c_city,'')
         ,  ISNULL(ORDERS.c_state,'')
         ,  ISNULL(ORDERS.c_zip,'') 
         ,  CASE WHEN ISDATE(ORDERS.userdefine03) = 1 THEN REPLACE(CONVERT(NVARCHAR(12),CAST(ORDERS.userdefine03 AS DATETIME),106),' ','-') ELSE '' END
         ,  REPLACE(CONVERT(NVARCHAR(12),ORDERS.DeliveryDate,106),' ','-')
         , CASE WHEN ISDATE(ORDERS.userdefine10) = 1 THEN REPLACE(CONVERT(NVARCHAR(12),CAST(ORDERS.userdefine10 AS DATETIME),106),' ','-') ELSE '' END
         , ODET.ODUDF02--ISNULL(OD.userdefine02,'')
         , ISNULL(ORDERS.userdefine04,'')  
         , ISNULL(TDI.Indicator,'')
   ORDER BY PACKHEADER.Loadkey
         ,  ISNULL(RTRIM(PACKDETAIL.LabelNo),'')
        -- ,  ISNULL(RTRIM(PACKDETAIL.CartonNo),'')
         ,  ISNULL(RTRIM(ORDERS.ExternOrderkey),'')
         ,  ISNULL(RTRIM(SKU.Style),'')
         --,  ISNULL(ORDERS.userdefine03,'')
         --,  ISNULL(ORDERS.userdefine10,'')
         ,  ODET.ODUDF02--ISNULL(OD.userdefine02,'') 
         ,  ISNULL(ORDERS.userdefine04,'')
         ,  ISNULL(ORDERS.c_Company,'')
         ,  ISNULL(ORDERS.c_address1,'')
         ,  ISNULL(ORDERS.c_address2,'')
         ,  ISNULL(ORDERS.c_address3,'')
         ,  ISNULL(ORDERS.c_city,'')
         ,  ISNULL(ORDERS.c_state,'')
         ,  ISNULL(ORDERS.c_zip,'')
         ,  CASE WHEN ISNULL(CL3.short,'') <> 'N' THEN ISNULL(ORDERS.ROUTE,'') ELSE '' END     --CS02
         ,  ISNULL(ORDERS.consigneekey,'')
         ,  ISNULL(ORDERS.storerkey,'')
         ,  ISNULL(ORDERS.facility,'')

END

GO