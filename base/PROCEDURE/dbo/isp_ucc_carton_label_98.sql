SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_UCC_Carton_Label_98                                 */
/* Creation Date: 16-DEC-2020                                           */
/* Copyright: LF Logistics                                              */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose: WMS-14992-[MY]-Carton Label Standardization_Packing_Module  */
/*        :                                                             */
/* Called By: r_dw_ucc_carton_label_98                                  */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_UCC_Carton_Label_98]
            @c_StorerKey      NVARCHAR(15) 
         ,  @c_PickSlipNo     NVARCHAR(10) 
         ,  @c_StartCartonNo  NVARCHAR(10) =''    
         ,  @c_EndCartonNo    NVARCHAR(10) ='' 
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT 

         ,@n_Maxline        INT
         ,@n_TTLCTN         INT
         ,@c_showttlctn     NVARCHAR(5)
         ,@c_getpickslipno  NVARCHAR(20)
         ,@c_getCartonno    NVARCHAR(5)
         

   CREATE TABLE #TMP_OD 
   (  Storerkey NVARCHAR(15)  NOT NULL DEFAULT('')
   ,  Sku       NVARCHAR(20)  NOT NULL DEFAULT('')
   ,  AltSku    NVARCHAR(20)  NOT NULL DEFAULT('')
   ) 

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1

   SET @n_Maxline = 9
   SET @n_TTLCTN = 1
   SET @c_getpickslipno = ''
   SET @c_getCartonno = ''

   IF EXISTS (SELECT 1 FROM PackDetail WITH (NOLOCK) WHERE PickSlipNo = @c_PickSlipNo )
   BEGIN
     SET @c_getpickslipno = @c_PickSlipNo
   END 
   ELSE
   BEGIN
        SELECT @c_getpickslipno = PickSlipNo
               ,@c_getCartonno = CartonNo
        FROM PackDetail WITH (NOLOCK) WHERE Storerkey = @c_StorerKey AND dropid = @c_PickSlipNo     

       SET @c_StartCartonNo = @c_getCartonno
       SET @c_EndCartonNo = @c_getCartonno

   END

   SELECT @n_ttlctn = MAX(cartonno)
   FROM PACKDETAIL WITH (NOLOCK)
   WHERE Pickslipno = @c_getpickslipno
   AND   Storerkey = @c_StorerKey 

   CREATE TABLE #TMP_LCartonLBL98 (
          rowid           int NOT NULL identity(1,1) PRIMARY KEY,
          Storerkey       NVARCHAR(20) NULL,
          OrdExtOrdKey    NVARCHAR(50) NULL,
          Consigneekey    NVARCHAR(45) NULL,
          cartonno        INT NULL,
          TTLCtn          INT NULL,
          SKUStyle        NVARCHAR(20) NULL,
          --SKUSize         NVARCHAR(10) NULL,
          --PDQty           INT,
          Facility        NVARCHAR(10) NULL,
          TTLQTY          INT,
          loadkey         NVARCHAR(20) NULL, 
          ExternPOKey     NVARCHAR(80) NULL,
          OHRoute         NVARCHAR(20) NULL,
          DropID          NVARCHAR(20) NULL,
          ST_Address1     NVARCHAR(45) NULL,
          ST_Address2     NVARCHAR(45) NULL,
          ST_Address3     NVARCHAR(45) NULL, 
          ST_City         NVARCHAR(45) NULL, 
          ST_State        NVARCHAR(45) NULL, 
          ST_Zip          NVARCHAR(45) NULL,
          RecGrp          INT,
          Pickslipno      NVARCHAR(20) NULL,
          ST_Company      NVARCHAR(45) NULL,
          Labelno         NVARCHAR(20) NULL,
          HIDETTLCTN      NVARCHAR(5) NULL,
          OHUDF10         NVARCHAR(30) NULL,
          MCompany        NVARCHAR(45) NULL)    


 CREATE TABLE #TMP_LCartonLBL98Date (
          rowid           int NOT NULL identity(1,1) PRIMARY KEY,
          Storerkey       NVARCHAR(20) NULL,
          OrdExtOrdKey    NVARCHAR(50) NULL,
          ODD_Date        DATETIME,
          OAD_Date        DATETIME,
          ODD             NVARCHAR(11),
          OAD             NVARCHAR(11),
          SLA             INT )

   insert into #TMP_LCartonLBL98 (Storerkey,OrdExtOrdKey,loadkey,OHRoute,Consigneekey,Facility,ttlqty,ExternPOKey,ST_Address1,
                                  ST_Address2,ST_Address3,ST_City,ST_State,ST_Zip,DropID,cartonno,SKUStyle,TTLCtn,RecGrp,Pickslipno,
                                  ST_Company,labelno,HideTTLCTN,OHUDF10,MCompany)
   SELECT DISTINCT OH.Storerkey,OH.ExternOrderkey,OH.Loadkey,OH.Route,OH.Consigneekey,
          OH.Facility,sum(PD.qty),OH.POKey,
          ST.Address1,ST.Address2,ST.Address3,
          ST.city,ST.state,ST.zip,PD.dropid , PD.CartonNo ,S.style,@n_ttlctn,
          ROW_NUMBER() OVER ( PARTITION BY OH.ExternOrderkey,PD.CartonNo  
                           ORDER BY OH.ExternOrderkey,cartonno ,style )/@n_Maxline + 1  as recgrp,PH.pickslipno,  
          ST.Company,PD.labelno, CASE WHEN ISNULL(CLR.Code,'') <> '' THEN 'Y' ELSE 'N' END AS Hidettlctn,
            CASE WHEN ISDATE(OH.UserDefine10) = 1 THEN CONVERT(NVARCHAR(11),CAST(OH.UserDefine10 AS DATETIME),106) ELSE '' END,ISNULL(OH.M_Company,'')    
   FROM ORDERS OH WITH (NOLOCK)
   --JOIN ORDERDETAIL OD WITH (NOLOCK) 
   JOIN PackHeader PH WITH (NOLOCK) ON PH.Orderkey = OH.Orderkey
   JOIN PACKDETAIL PD WITH (NOLOCK) ON PD.Pickslipno = PH.pickslipno
   LEFT JOIN STORER ST WITH (NOLOCK) ON ST.Storerkey = OH.Consigneekey
   LEFT JOIN SKU S WITH (NOLOCK) ON S.storerkey = PD.Storerkey AND S.SKU = PD.SKU 
   LEFT JOIN storersodefault SOD WITH (NOLOCK) ON SOD.storerkey = ST.Storerkey
   LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.listname = 'SLABYREGION' AND C.short=SOD.destination
   LEFT OUTER JOIN Codelkup CLR (NOLOCK) ON (OH.Storerkey = CLR.Storerkey AND CLR.Code = 'HIDETTLCTN'
                                       AND CLR.Listname = 'REPORTCFG' AND CLR.Long = 'r_dw_ucc_carton_label_98' AND ISNULL(CLR.Short,'') <> 'N')
   WHERE PH.pickslipno = @c_getpickslipno
   AND OH.StorerKey = @c_storerkey
   AND PD.cartonno >= CASE WHEN @c_StartCartonNo <> '' THEN CAST(@c_StartCartonNo as INT) ELSE PD.cartonno END
   AND PD.cartonno <= CASE WHEN @c_EndCartonNo <> '' THEN CAST(@c_EndCartonNo as INT) ELSE PD.cartonno END
   GROUP BY OH.Storerkey,OH.ExternOrderkey,OH.Loadkey,OH.Route,OH.Consigneekey,
          OH.Facility,OH.POKey,
          ST.Address1,ST.Address2,ST.Address3,
          ST.city,ST.state,ST.zip,PD.dropid , PD.CartonNo ,S.style,PH.pickslipno,ST.company,PD.labelno,
          CASE WHEN ISNULL(CLR.Code,'') <> '' THEN 'Y' ELSE 'N' END ,
          CASE WHEN ISDATE(OH.UserDefine10) = 1 THEN CONVERT(NVARCHAR(11),CAST(OH.UserDefine10 AS DATETIME),106) ELSE '' END,ISNULL(OH.M_Company,'')     
   order by PH.pickslipno ,OH.ExternOrderkey,PD.cartonno , S.style  

   INSERT INTO #TMP_LCartonLBL98Date (Storerkey,OrdExtOrdKey,ODD_Date,OAD_Date,ODD,OAD,SLA)
   SELECT DISTINCT OH.Storerkey,OH.ExternOrderkey,
                   CASE WHEN OH.StorerKey in ('Adidas') AND ISDATE(OH.Userdefine03 ) = 1 THEN CONVERT(DATETIME,OH.Userdefine03 ) 
                        ELSE OH.DeliveryDate END,OH.DeliveryDate,'','',
                   CASE WHEN ISNUMERIC(c.long) = 1 THEN CAST(C.long as INT) ELSE 0 END
   FROM ORDERS OH WITH (NOLOCK)
   --JOIN ORDERDETAIL OD WITH (NOLOCK) 
   JOIN PackHeader PH WITH (NOLOCK) ON PH.Orderkey = OH.Orderkey
   JOIN PACKDETAIL PD WITH (NOLOCK) ON PD.Pickslipno = PH.pickslipno
   LEFT JOIN STORER ST WITH (NOLOCK) ON ST.Storerkey = OH.Storerkey
   LEFT JOIN SKU S WITH (NOLOCK) ON S.storerkey = PD.Storerkey AND S.SKU = PD.SKU 
   LEFT JOIN storersodefault SOD WITH (NOLOCK) ON SOD.storerkey = ST.Storerkey
   LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.listname = 'SLABYREGION' AND C.short=SOD.destination
   where PH.pickslipno = @c_getpickslipno
   AND OH.StorerKey = @c_storerkey


update #TMP_LCartonLBL98Date
SET ODD = CASE WHEN storerkey = 'Skechers' THEN CONVERT(NVARCHAR(11),ODD_date - SLA,106) ELSE CONVERT(NVARCHAR(11),ODD_Date,106) END
   ,OAD = CASE WHEN storerkey in ('NIKEMY','JDSPORTSMY','TBLMY') THEN CONVERT(NVARCHAR(11),ODD_date + SLA,106) ELSE CONVERT(NVARCHAR(11),OAD_Date,106) END

QUIT_SP:
   
    SELECT a.loadkey,a.OrdExtOrdKey as externorderkey,a.TTLCtn as CtnCnt1,a.cartonno,a.DropID,a.SKUStyle as style,
           a.Storerkey,a.ttlqty as sizeqty,a.OHRoute,a.Consigneekey,a.Facility,
            CASE WHEN ISNULL(a.ExternPOKey,'') <> '' AND ISNULL(a.MCompany,'') <> '' THEN a.ExternPOKey + '/' + a.MCompany
                 WHEN ISNULL(a.ExternPOKey,'') <> '' AND ISNULL(a.MCompany,'') = '' THEN a.ExternPOKey
                 WHEN ISNULL(a.ExternPOKey,'') = '' AND ISNULL(a.MCompany,'') <> '' THEN a.MCompany
             ELSE '' END  AS ExternPOKey 
           ,a.ST_Address1,
           a.ST_Address2,a.ST_Address3,a.ST_City,a.ST_State,a.ST_Zip,a.RecGrp,a.Pickslipno
          ,REPLACE(b.ODD,' ' ,'-') AS ODD,REPLACE(b.OAD,' ' ,'-') AS OAD,a.ST_Company,a.labelno,a.HIDETTLCTN as hidettlctn,
           REPLACE(a.OHUDF10,' ' ,'-') AS OHUDF10
    FROM #TMP_LCartonLBL98 a
    JOIN #TMP_LCartonLBL98Date b on b.storerkey = a.storerkey and b.OrdExtOrdKey=a.OrdExtOrdKey 
    WHERE a.pickslipno = @c_getpickslipno
    AND a.StorerKey = @c_storerkey
   AND a.cartonno >= CASE WHEN @c_StartCartonNo <> '' THEN CAST(@c_StartCartonNo as INT) ELSE a.cartonno END
   AND a.cartonno <= CASE WHEN @c_EndCartonNo <> '' THEN CAST(@c_EndCartonNo as INT) ELSE a.cartonno END
    ORDER BY a.Pickslipno,a.OrdExtOrdKey,a.cartonno,a.SKUStyle

drop table #TMP_LCartonLBL98

drop table #TMP_LCartonLBL98Date  


END -- procedure

GO