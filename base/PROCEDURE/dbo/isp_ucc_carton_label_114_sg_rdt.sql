SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Stored Procedure: isp_UCC_Carton_Label_114_sg_rdt                    */
/* Creation Date: 05-Apr-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: CHONGCS                                                  */
/*                                                                      */
/* Purpose: WMS-19384 - [SG] adidas û Carton Label                      */
/*                                                                      */
/* Called By: r_dw_UCC_Carton_Label_114_sg_rdt                          */
/*                                                                      */
/* GitLab Version: 1.2                                                  */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver   Purposes                                  */
/* 2022-04-06  CHONGCS  1.0   Created - DevOps Combine Script           */
/* 2022-04-29  CSCHONG  1.1   WMS-19384 fix route mapping (CS01)        */
/* 2022-05-24  CSCHONG  1.2   WMS-19384 change dropid to labelno (CS02) */
/************************************************************************/
CREATE PROC [dbo].[isp_UCC_Carton_Label_114_sg_rdt] (
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
           @c_UOM          NVARCHAR(10),
           @c_pickslipno   NVARCHAR(20) ,
           @c_NOTPPA       NVARCHAR(1) = 'N' ,  
           @c_chkNOTPPA1   NVARCHAR(1) ='N',
           @c_chkNOTPPA2   NVARCHAR(1) = 'N' 
   

   SET @b_debug = 0
   SET @n_Maxline = 9


DECLARE @t_DropID TABLE (  
      LabelNo      NVARCHAR(20)
    , Indicator    NVARCHAR(10)
   )

   SELECT @c_pickslipno = PH.PickSlipNo  
         ,@c_Storerkey = PH.StorerKey
         ,@c_LabelNo = PD.LabelNo
   FROM PACKHEADER PH WITH (NOLOCK)                                         
   JOIN PACKDETAIL PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)  
   WHERE PD.dropid = @c_DropID AND PD.Storerkey = 'ADIDAS'                        

   --DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   --SELECT DISTINCT PD.LabelNo, PD.StorerKey
   --FROM PACKDETAIL PD (NOLOCK)
   --WHERE PD.DROPID = @c_DropID

   --OPEN CUR_LOOP

   --FETCH NEXT FROM CUR_LOOP INTO @c_LabelNo, @c_Storerkey

   --WHILE @@FETCH_STATUS <> -1
   --BEGIN
      IF EXISTS (SELECT 1 FROM PICKDETAIL (NOLOCK) 
                 WHERE DropID = @c_LabelNo                         --CS02 
                 AND Storerkey = @c_Storerkey
                 AND UOM = '2')
      BEGIN
         INSERT INTO @t_DropID (LabelNo, Indicator)
         SELECT @c_LabelNo, 'FC'
      END
      --CS01 S
       IF EXISTS (SELECT 1 FROM ORDERS OH WITH (NOLOCK)
                  JOIN PackHeader PH WITH (NOLOCK) ON PH.OrderKey=OH.OrderKey
                  WHERE PH.PickSlipNo =@c_pickslipno AND PH.StorerKey = @c_Storerkey
                  AND ISNULL(OH.M_vat,'') = 'PPA')
      BEGIN   


             IF EXISTS 
            ( SELECT 1 FROM PackDetail PAD
                LEFT JOIN rdt.RdtPPA PPA ON PPA.Storerkey = @c_Storerkey And PPA.DropID = @c_DropID And PPA.Sku = PAD.SKU
                Where PAD.Storerkey = @c_Storerkey
               AND PAD.DropID = @c_DropID                            
                HAVING sum(PAD.Qty) <> sum(IsNull(PPA.CQty,0))
            )
            BEGIN
               SET @c_chkNOTPPA1 = 'Y'
            END

            IF EXISTS
            ( SELECT 1 FROM rdt.RDTPPA PPA
                Where PPA.Storerkey = @c_Storerkey 
               And PPA.DropID = @c_DropID
                And PPA.CQty > 0 
                And NOT EXISTS (SELECT 1 
                           FROM PackDetail PAD WHERE PAD.Storerkey = @c_Storerkey
                           AND PAD.DropID = @c_DropID                  
                           And PAD.Sku = PPA.SKU)
            )
            BEGIN
               SET @c_chkNOTPPA2 = 'Y'
            END
        END   --CS01 E
            IF @c_chkNOTPPA1 = 'Y' OR @c_chkNOTPPA2 = 'Y'
            BEGIN
              SET @c_NOTPPA = 'Y' 
            END

   --   FETCH NEXT FROM CUR_LOOP INTO @c_LabelNo, @c_Storerkey
   --END
   --CLOSE CUR_LOOP
   --DEALLOCATE CUR_LOOP

   SELECT Loadkey        = ORDERS.Loadkey
         ,ExternOrderkey = ISNULL(RTRIM(ORDERS.ExternOrderkey),'')
         ,CtnCnt1        = (SELECT COUNT(DISTINCT PD.LabelNo)
                            FROM PACKHEADER PH WITH (NOLOCK)
                            JOIN PACKDETAIL PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
                            WHERE PH.PickSlipNo = @c_Pickslipno)
         ,Cartonno = (Select Count(Distinct PD2.Cartonno) 
                      FROM PackDetail PD2 
                      WHERE PD2.Cartonno < PACKDETAIL.Cartonno + 1 AND PD2.PickSlipNo = @c_pickslipno)
         ,DropID         = ISNULL(RTRIM(PACKDETAIL.dropid),'')
         ,Style          = ISNULL(RTRIM(SKU.Style),'')
         ,Storerkey      = ISNULL(ORDERS.storerkey,'')
        -- ,SkuDesc        = ''--ISNULL(RTRIM(SKU.Descr),'')
         ,SizeQty        = SUM(PACKDETAIL.Qty)
         ,OHRoute        = CASE WHEN PACKHEADER.Status <> '9' THEN 'NOTPACK' ELSE CASE WHEN @c_NOTPPA = 'Y' THEN  'NOTPPA' ELSE ORDERS.[Route] END END  --ISNULL(ORDERS.ROUTE,'')
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
         ,UserkeyOverride= PACKHEADER.editwho--TD.UserkeyOverride   
         ,BuyerPO        = ISNULL(ORDERS.BuyerPO,'')  
         ,ST_Company     = ISNULL(ORDERS.c_Company,'') 
         ,ODD            = CASE WHEN ISDATE(ORDERS.userdefine03) = 1 THEN REPLACE(CONVERT(NVARCHAR(12),CAST(ORDERS.userdefine03 AS DATETIME),106),' ','-') ELSE '' END
         ,DELDate        = REPLACE(CONVERT(NVARCHAR(12),ORDERS.DeliveryDate,106),' ','-')
         ,oad            = CASE WHEN ISDATE(ORDERS.userdefine10) = 1 THEN REPLACE(CONVERT(NVARCHAR(12),CAST(ORDERS.userdefine10 AS DATETIME),106),' ','-') ELSE '' END
         ,ODUDF02        = ODET.ODUDF02
         ,OHUDF04        = ISNULL(ORDERS.userdefine04,'')   
         ,Prefix         = ISNULL(PF.Dvprefix,'')
         ,FCIndicator    = ISNULL(TDI.Indicator,'')
   FROM PACKHEADER WITH (NOLOCK)
   JOIN PACKDETAIL WITH (NOLOCK) ON (PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo)
   JOIN SKU WITH (NOLOCK) ON (PACKDETAIL.Storerkey = SKU.Storerkey)
                         AND (PACKDETAIL.Sku = SKU.Sku)
   JOIN ORDERS WITH (NOLOCK) ON (PACKHEADER.Orderkey = ORDERS.Orderkey)
   OUTER APPLY (SELECT TOP 1 ISNULL(OD.userdefine02,'') AS ODUDF02 
                 FROM ORDERDETAIL OD (NOLOCK) WHERE OD.ORDERKEY = ORDERS.ORDERKEY) ODET
   --JOIN ORDERDETAIL OD WITH (NOLOCK) ON OD.Orderkey = ORDERS.Orderkey 
   --LEFT JOIN CODELKUP CL WITH (NOLOCK) ON (CL.LISTNAME = 'REPORTCFG' AND CL.CODE = 'ShowPONo' )
   --                                   AND (CL.LONG = 'r_dw_UCC_Carton_Label_114_sg_rdt' AND CL.STORERKEY = ORDERS.Storerkey)
   --LEFT JOIN CODELKUP CL1 WITH (NOLOCK) ON (CL1.LISTNAME = 'REPORTCFG' AND CL1.CODE = 'ShowDNNo' )
   --                                    AND (CL1.LONG = 'r_dw_UCC_Carton_Label_114_sg_rdt' AND CL1.STORERKEY = ORDERS.Storerkey)
   --LEFT JOIN CODELKUP CL2 WITH (NOLOCK) ON (CL2.LISTNAME = 'REPORTCFG' AND CL2.CODE = 'ShowSONo' )
   --                                    AND (CL2.LONG = 'r_dw_UCC_Carton_Label_114_sg_rdt' AND CL2.STORERKEY = ORDERS.Storerkey)
   --LEFT JOIN CODELKUP CL3 WITH (NOLOCK) ON (CL3.LISTNAME = 'REPORTCFG' AND CL3.CODE = 'ShowRoute' )
   --                                    AND (CL3.LONG = 'r_dw_UCC_Carton_Label_114_sg_rdt' AND CL3.STORERKEY = ORDERS.Storerkey)
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
   LEFT JOIN @t_DropID TDI ON TDI.LabelNo = PACKDETAIL.labelno                      --CS02                     
   WHERE PACKDETAIL.DropID = @c_DropID AND PACKDETAIL.Storerkey = 'ADIDAS'      
   --AND PACKD.CartonNo BETWEEN CAST(@c_FromCartonNo AS INT) AND CAST(@c_ToCartonNo AS INT)
   --AND PACKDETAIL.LabelNo BETWEEN @c_FromLabelNo AND @c_ToLabelNo
   GROUP BY ORDERS.Loadkey
         ,  ISNULL(RTRIM(ORDERS.ExternOrderkey),'')
         ,  ISNULL(RTRIM(PACKDETAIL.CartonNo),'')
         ,  ISNULL(RTRIM(PACKDETAIL.dropid),'')
         ,  ISNULL(RTRIM(SKU.Style),'')
         --,  ISNULL(RTRIM(SKU.Descr),'')
        -- ,  ISNULL(CL.SHORT,'N')
        -- ,  ISNULL(CL1.SHORT,'N')
         ,  ISNULL(PIF.CartonType,'')    
         ,  ISNULL(ORDERS.M_VAT,'')  
         ,  PACKHEADER.editwho --TD.UserkeyOverride           
         ,  ISNULL(ORDERS.BuyerPO,'')   
         ,  ISNULL(PF.Dvprefix,'')
         ,  PACKDETAIL.Cartonno  
         ,  ISNULL(ORDERS.storerkey,'')
         ,  ORDERS.[Route]
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
        -- , ISNULL(OD.userdefine02,'')
         , ISNULL(ORDERS.userdefine04,'')  
         , ISNULL(TDI.Indicator,'')   
         , PackHeader.status     
         , ODET.ODUDF02     
   ORDER BY ORDERS.Loadkey
         ,  ISNULL(RTRIM(PACKDETAIL.dropid),'')
        -- ,  ISNULL(RTRIM(PACKDETAIL.CartonNo),'')
         ,  ISNULL(RTRIM(ORDERS.ExternOrderkey),'')
         ,  ISNULL(RTRIM(SKU.Style),'')
         --,  ISNULL(ORDERS.userdefine03,'')
         --,  ISNULL(ORDERS.userdefine10,'')
        -- ,  ISNULL(OD.userdefine02,'') 
         ,  ODET.ODUDF02   
         ,  ISNULL(ORDERS.userdefine04,'')
         ,  ISNULL(ORDERS.c_Company,'')
         ,  ISNULL(ORDERS.c_address1,'')
         ,  ISNULL(ORDERS.c_address2,'')
         ,  ISNULL(ORDERS.c_address3,'')
         ,  ISNULL(ORDERS.c_city,'')
         ,  ISNULL(ORDERS.c_state,'')
         ,  ISNULL(ORDERS.c_zip,'')
         ,  ISNULL(ORDERS.ROUTE,'')
         ,  ISNULL(ORDERS.consigneekey,'')
         ,  ISNULL(ORDERS.storerkey,'')
         ,  ISNULL(ORDERS.facility,'')

END

GO