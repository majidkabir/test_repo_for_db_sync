SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_UCC_Carton_Label_101                                */
/* Creation Date: 15-FEB-2021                                           */
/* Copyright: LF Logistics                                              */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose: WMS-16309-[MY]-NIKEMY Carton Label Modification For Label   */
/*                    Standardization-[CR]                              */
/*        :                                                             */
/* Called By: r_dw_ucc_carton_label_101                                 */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 05-OCT-2021 CSCHONG  1.0   Devops scripts combine                    */
/* 26-JAN-2022 MINGLE   1.1   WMS-18832 - Change all address's table    */
/*                            from ST to OH(column name unchanged)(ML01)*/
/************************************************************************/
CREATE PROC [dbo].[isp_UCC_Carton_Label_101]
            @c_StorerKey      NVARCHAR(15) 
         ,  @c_PickSlipNo     NVARCHAR(10) 
         ,  @c_StartCartonNo  NVARCHAR(10)     
         ,  @c_EndCartonNo    NVARCHAR(10)  
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
         ,@c_PrnByDropid    NVARCHAR(1)
         ,@n_TTLQtyByDropid  INT   = 0
         ,@c_hideuccbarcode  NVARCHAR(5) = 'N'
         

   CREATE TABLE #TMP_PSNO
   (  Storerkey        NVARCHAR(20)  NOT NULL DEFAULT('')
   ,  Pickslipno       NVARCHAR(20)  NOT NULL DEFAULT('')
   ,  loadkey          NVARCHAR(20)  NOT NULL DEFAULT('')
   ,  Dropid           NVARCHAR(50)  NULL DEFAULT ('')
   ,  Model            NVARCHAR(50)  NULL DEFAULT ('')
   ,  labelno          NVARCHAR(20) NULL DEFAULT ('')
   ,  Refno2           NVARCHAR(30) NULL DEFAULT ('')
   ,  Qty              INT
   ) 

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1

   SET @n_Maxline = 9
   SET @n_TTLCTN = 1
   SET @c_getpickslipno = ''
   SET @c_getCartonno = ''
   SET @c_PrnByDropid = 'N'


   SELECT @c_hideuccbarcode = CASE WHEN ISNULL(CLR1.Code,'') <> '' THEN 'Y' ELSE 'N' END
   FROM Codelkup CLR1 (NOLOCK) 
   WHERE  CLR1.Storerkey  = @c_StorerKey
    AND CLR1.Code = 'HIDEUCCBARCODE'
    AND CLR1.Listname = 'REPORTCFG' AND CLR1.Long = 'r_dw_ucc_carton_label_101' AND ISNULL(CLR1.Short,'') <> 'N'

   IF EXISTS (SELECT 1 FROM PackDetail WITH (NOLOCK) WHERE PickSlipNo = @c_PickSlipNo )
   BEGIN
     INSERT INTO #TMP_PSNO(Storerkey,Pickslipno,loadkey,Dropid,Model,labelno,Refno2,Qty)
     SELECT PH.StorerKey,PH.PickSlipNo,PH.LoadKey,'','','','',0
     FROM dbo.PackHeader PH WITH (NOLOCK)
    -- JOIN PackDetail PD WITH (NOLOCK) ON PD.PickSlipNo =PH.PickSlipNo
     WHERE PH.PickSlipNo=@c_PickSlipNo
   END 
   ELSE
   BEGIN
       --SELECT @c_getpickslipno = MAX(PD.pickslipno)
       --FROM  dbo.PackHeader PH WITH (NOLOCK)
       --JOIN PackDetail PD WITH (NOLOCK) ON PD.PickSlipNo =PH.PickSlipNo
       --WHERE PH.Storerkey = @c_StorerKey AND PD.dropid = @c_PickSlipNo     
   IF @c_hideuccbarcode = 'N'
   BEGIN
       INSERT INTO #TMP_PSNO(Storerkey,Pickslipno,loadkey,Dropid,Model,labelno,Refno2,Qty)
       SELECT DISTINCT PH.StorerKey,@c_getpickslipno,PH.LoadKey,pd.DropID,
            (SUBSTRING(s.busr10, 1, CHARINDEX('-', s.busr10) - 1)) + '-' + (SUBSTRING(s.busr10, CHARINDEX('-', s.busr10) + 1, 
           (CHARINDEX('-', s.busr10, CHARINDEX('-', s.busr10) + 1))-(CHARINDEX('-', s.busr10)+1))),pd.LabelNo,pd.RefNo2,SUM(pd.qty)
        --SELECT @c_getpickslipno = MIN(PickSlipNo)
        --       ,@c_getCartonno = MIN(RefNo2)
        FROM  dbo.PackHeader PH WITH (NOLOCK)
        JOIN PackDetail PD WITH (NOLOCK) ON PD.PickSlipNo =PH.PickSlipNo
         LEFT JOIN SKU S WITH (NOLOCK) ON S.storerkey = PD.Storerkey AND S.SKU = PD.SKU 
        WHERE PH.Storerkey = @c_StorerKey AND PD.dropid = @c_PickSlipNo     
        GROUP BY PH.StorerKey,PH.LoadKey,pd.DropID,(SUBSTRING(s.busr10, 1, CHARINDEX('-', s.busr10) - 1)) + '-' + (SUBSTRING(s.busr10, CHARINDEX('-', s.busr10) + 1, 
           (CHARINDEX('-', s.busr10, CHARINDEX('-', s.busr10) + 1))-(CHARINDEX('-', s.busr10)+1))),pd.LabelNo,pd.RefNo2
   END
   ELSE
   BEGIN
      INSERT INTO #TMP_PSNO(Storerkey,Pickslipno,loadkey,Dropid,Model,labelno,Refno2,Qty)
       SELECT DISTINCT PH.StorerKey,MAX(ph.PickSlipNo),PH.LoadKey,pd.DropID,
            (SUBSTRING(s.busr10, 1, CHARINDEX('-', s.busr10) - 1)) + '-' + (SUBSTRING(s.busr10, CHARINDEX('-', s.busr10) + 1, 
           (CHARINDEX('-', s.busr10, CHARINDEX('-', s.busr10) + 1))-(CHARINDEX('-', s.busr10)+1))),MAX(pd.LabelNo),pd.RefNo2,SUM(pd.qty)
        --SELECT @c_getpickslipno = MIN(PickSlipNo)
        --       ,@c_getCartonno = MIN(RefNo2)
        FROM  dbo.PackHeader PH WITH (NOLOCK)
        JOIN PackDetail PD WITH (NOLOCK) ON PD.PickSlipNo =PH.PickSlipNo
         LEFT JOIN SKU S WITH (NOLOCK) ON S.storerkey = PD.Storerkey AND S.SKU = PD.SKU 
        WHERE PH.Storerkey = @c_StorerKey AND PD.dropid = @c_PickSlipNo     
        GROUP BY PH.StorerKey,PH.LoadKey,pd.DropID,(SUBSTRING(s.busr10, 1, CHARINDEX('-', s.busr10) - 1)) + '-' + (SUBSTRING(s.busr10, CHARINDEX('-', s.busr10) + 1, 
           (CHARINDEX('-', s.busr10, CHARINDEX('-', s.busr10) + 1))-(CHARINDEX('-', s.busr10)+1))),pd.RefNo2
   END
       SET @c_StartCartonNo = 1 --@c_getCartonno
       SET @c_EndCartonNo = 99999--@c_getCartonno

      SELECT @n_ttlctn = COUNT(DISTINCT PD.dropid)
      FROM #TMP_PSNO TP
      JOIN  dbo.PackHeader PH WITH (NOLOCK) ON PH.loadkey =TP.loadkey  
      JOIN PackDetail PD WITH (NOLOCK) ON PD.PickSlipNo =PH.PickSlipNo  
     
      SELECT @n_TTLQtyByDropid = SUM(PD.qty)
      FROM #TMP_PSNO TP
      JOIN  dbo.PackHeader PH WITH (NOLOCK) ON PH.loadkey =TP.loadkey  
      JOIN PackDetail PD WITH (NOLOCK) ON PD.PickSlipNo =PH.PickSlipNo  
      WHERE PD.DropID = @c_PickSlipNo

     SET @c_PrnByDropid = 'Y'

     --SELECT @n_TTLQtyByDropid '@n_TTLQtyByDropid'

   END

    --SELECT * FROM #TMP_PSNO

   CREATE TABLE #TMP_LCartonLBL101 (
          rowid           int NOT NULL identity(1,1) PRIMARY KEY,
          Storerkey       NVARCHAR(20) NULL,
          OrdExtOrdKey    NVARCHAR(50) NULL,
          Consigneekey    NVARCHAR(45) NULL,
          cartonno        INT NULL,
          TTLCtn          INT NULL,
          SKUStyle        NVARCHAR(30) NULL,
          --SKUSize         NVARCHAR(10) NULL,
          --PDQty           INT,
          Facility        NVARCHAR(10) NULL,
          TTLQTY          INT,
          loadkey         NVARCHAR(20) NULL, 
          ExternPOKey     NVARCHAR(20) NULL,
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
          HIDEUCCBARCODE  NVARCHAR(5) NULL,
          PrnByDropID     NVARCHAR(1) NULL)    


 CREATE TABLE #TMP_LCartonLBL101Date (
          rowid           int NOT NULL identity(1,1) PRIMARY KEY,
          Storerkey       NVARCHAR(20) NULL,
          OrdExtOrdKey    NVARCHAR(50) NULL,
          ODD_Date        DATETIME,
          OAD_Date        DATETIME,
          ODD             NVARCHAR(11),
          OAD             NVARCHAR(11),
          SLA             INT )
 
IF @c_PrnByDropid = 'N'
BEGIN
   insert into #TMP_LCartonLBL101 (Storerkey,OrdExtOrdKey,loadkey,OHRoute,Consigneekey,Facility,ttlqty,ExternPOKey,ST_Address1,
                                  ST_Address2,ST_Address3,ST_City,ST_State,ST_Zip,DropID,cartonno,SKUStyle,TTLCtn,RecGrp,Pickslipno,
                                  ST_Company,labelno,HideTTLCTN,HIDEUCCBARCODE,PrnByDropID)        
   SELECT DISTINCT OH.Storerkey,OH.ExternOrderkey,OH.Loadkey,OH.Route,OH.Consigneekey,
          OH.Facility,SUM(PD.qty),
          OH.ExternPOKey,OH.C_Address1,OH.C_Address2,OH.C_Address3,  --ML01
          OH.C_city,OH.C_state,OH.C_zip,PD.dropid , PD.RefNo2 ,--SUBSTRING(s.busr10,1,CHARINDEX('-',s.busr10) -1),
          (SUBSTRING(s.busr10, 1, CHARINDEX('-', s.busr10) - 1)) + '-' + (SUBSTRING(s.busr10, CHARINDEX('-', s.busr10) + 1, 
           (CHARINDEX('-', s.busr10, CHARINDEX('-', s.busr10) + 1))-(CHARINDEX('-', s.busr10)+1))),  
          --TPS.model,
          @n_ttlctn,
          ROW_NUMBER() OVER ( PARTITION BY OH.ExternOrderkey,PD.RefNo2  
                           ORDER BY OH.ExternOrderkey,PD.RefNo2 ,(SUBSTRING(s.busr10, 1, CHARINDEX('-', s.busr10) - 1)) + '-' + (SUBSTRING(s.busr10, CHARINDEX('-', s.busr10) + 1, 
           (CHARINDEX('-', s.busr10, CHARINDEX('-', s.busr10) + 1))-(CHARINDEX('-', s.busr10)+1))) )/@n_Maxline + 1  as recgrp,PH.pickslipno,  
          --ROW_NUMBER() OVER ( PARTITION BY OH.ExternOrderkey,PD.RefNo2  
          --                 ORDER BY OH.ExternOrderkey,PD.RefNo2 ,tps.model)/@n_Maxline + 1  as recgrp,PH.pickslipno,
          OH.C_Company,PD.labelno, CASE WHEN ISNULL(CLR.Code,'') <> '' THEN 'Y' ELSE 'N' END AS Hidettlctn,  
          CASE WHEN ISNULL(CLR1.Code,'') <> '' THEN 'Y' ELSE 'N' END AS Hideuccbarcode ,@c_PrnByDropid 
   FROM ORDERS OH WITH (NOLOCK)
   --JOIN ORDERDETAIL OD WITH (NOLOCK) 
   JOIN PackHeader PH WITH (NOLOCK) ON PH.Orderkey = OH.Orderkey
   JOIN PACKDETAIL PD WITH (NOLOCK) ON PD.Pickslipno = PH.pickslipno
   LEFT JOIN STORER ST WITH (NOLOCK) ON ST.Storerkey = OH.Consigneekey
   LEFT JOIN SKU S WITH (NOLOCK) ON S.storerkey = PD.Storerkey AND S.SKU = PD.SKU 
   LEFT JOIN storersodefault SOD WITH (NOLOCK) ON SOD.storerkey = ST.Storerkey
   LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.listname = 'SLABYREGION' AND C.short=SOD.destination
   LEFT OUTER JOIN Codelkup CLR (NOLOCK) ON (OH.Storerkey = CLR.Storerkey AND CLR.Code = 'HIDETTLCTN'
                                       AND CLR.Listname = 'REPORTCFG' AND CLR.Long = 'r_dw_ucc_carton_label_101' AND ISNULL(CLR.Short,'') <> 'N')
   LEFT OUTER JOIN Codelkup CLR1 (NOLOCK) ON (OH.Storerkey = CLR1.Storerkey AND CLR1.Code = 'HIDEUCCBARCODE'
                                       AND CLR1.Listname = 'REPORTCFG' AND CLR1.Long = 'r_dw_ucc_carton_label_101' AND ISNULL(CLR1.Short,'') <> 'N')
   JOIN #TMP_PSNO TPS ON TPS.Pickslipno = PH.PickSlipNo AND TPS.Storerkey = PH.StorerKey
   --WHERE PH.pickslipno = @c_getpickslipno
   --AND OH.StorerKey = @c_storerkey
   WHERE PD.cartonno >= CASE WHEN @c_PrnByDropid = 'N' THEN CAST(@c_StartCartonNo as INT) ELSE PD.cartonno END
   AND PD.cartonno <= CASE WHEN @c_PrnByDropid = 'N' THEN CAST(@c_EndCartonNo as INT) ELSE PD.cartonno END
   AND PD.DropID = CASE WHEN @c_PrnByDropid='Y' THEN @c_PickSlipNo ELSE PD.DropID END
   GROUP BY OH.Storerkey,OH.ExternOrderkey,OH.Loadkey,OH.Route,OH.Consigneekey,
          OH.Facility,OH.ExternPOKey,OH.C_Address1,OH.C_Address2,OH.C_Address3,
          OH.C_city,OH.C_state,OH.C_zip,PD.dropid , PD.refno2 ,--SUBSTRING(s.busr10,1,CHARINDEX('-',s.busr10) -1),
          (SUBSTRING(s.busr10, 1, CHARINDEX('-', s.busr10) - 1)) + '-' + (SUBSTRING(s.busr10, CHARINDEX('-', s.busr10) + 1, 
           (CHARINDEX('-', s.busr10, CHARINDEX('-', s.busr10) + 1))-(CHARINDEX('-', s.busr10)+1))), 
          PH.pickslipno,OH.C_company,PD.labelno,
          CASE WHEN ISNULL(CLR.Code,'') <> '' THEN 'Y' ELSE 'N' END,
          CASE WHEN ISNULL(CLR1.Code,'') <> '' THEN 'Y' ELSE 'N' END       
   order by PH.pickslipno ,OH.ExternOrderkey,PD.RefNo2 ,--SUBSTRING(s.busr10,1,CHARINDEX('-',s.busr10) -1),
          (SUBSTRING(s.busr10, 1, CHARINDEX('-', s.busr10) - 1)) + '-' + (SUBSTRING(s.busr10, CHARINDEX('-', s.busr10) + 1, 
           (CHARINDEX('-', s.busr10, CHARINDEX('-', s.busr10) + 1))-(CHARINDEX('-', s.busr10)+1)))
END
ELSE
BEGIN

      insert into #TMP_LCartonLBL101 (Storerkey,OrdExtOrdKey,loadkey,OHRoute,Consigneekey,Facility,ttlqty,ExternPOKey,ST_Address1,
                                  ST_Address2,ST_Address3,ST_City,ST_State,ST_Zip,DropID,cartonno,SKUStyle,TTLCtn,RecGrp,Pickslipno,
                                  ST_Company,labelno,HideTTLCTN,HIDEUCCBARCODE,PrnByDropID) 
   SELECT DISTINCT OH.Storerkey,OH.ExternOrderkey,OH.Loadkey,OH.Route,OH.Consigneekey,
          OH.Facility, SUM(tps.qty) ,
          OH.ExternPOKey,OH.C_Address1,OH.C_Address2,OH.C_Address3,
          OH.C_city,OH.C_state,OH.C_zip,tps.dropid , tps.RefNo2 ,--SUBSTRING(s.busr10,1,CHARINDEX('-',s.busr10) -1),
          --(SUBSTRING(s.busr10, 1, CHARINDEX('-', s.busr10) - 1)) + '-' + (SUBSTRING(s.busr10, CHARINDEX('-', s.busr10) + 1, 
          -- (CHARINDEX('-', s.busr10, CHARINDEX('-', s.busr10) + 1))-(CHARINDEX('-', s.busr10)+1))),  
          TPS.model,
          @n_ttlctn,
          --ROW_NUMBER() OVER ( PARTITION BY OH.ExternOrderkey,PD.RefNo2  
          --                 ORDER BY OH.ExternOrderkey,PD.RefNo2 ,(SUBSTRING(s.busr10, 1, CHARINDEX('-', s.busr10) - 1)) + '-' + (SUBSTRING(s.busr10, CHARINDEX('-', s.busr10) + 1, 
          -- (CHARINDEX('-', s.busr10, CHARINDEX('-', s.busr10) + 1))-(CHARINDEX('-', s.busr10)+1))) )/@n_Maxline + 1  as recgrp,PH.pickslipno,  
          ROW_NUMBER() OVER ( PARTITION BY OH.ExternOrderkey,tps.RefNo2  
                           ORDER BY OH.ExternOrderkey,tps.RefNo2 ,tps.model)/@n_Maxline + 1  as recgrp,PH.pickslipno,
          OH.C_Company,tps.labelno, CASE WHEN ISNULL(CLR.Code,'') <> '' THEN 'Y' ELSE 'N' END AS Hidettlctn,  
          CASE WHEN ISNULL(CLR1.Code,'') <> '' THEN 'Y' ELSE 'N' END AS Hideuccbarcode ,@c_PrnByDropid 
   FROM ORDERS OH WITH (NOLOCK)
   --JOIN ORDERDETAIL OD WITH (NOLOCK) 
   JOIN PackHeader PH WITH (NOLOCK) ON PH.Orderkey = OH.Orderkey
 --  JOIN PACKDETAIL PD WITH (NOLOCK) ON PD.Pickslipno = PH.pickslipno
   LEFT JOIN STORER ST WITH (NOLOCK) ON ST.Storerkey = OH.Consigneekey
  -- LEFT JOIN SKU S WITH (NOLOCK) ON S.storerkey = PD.Storerkey AND S.SKU = PD.SKU 
   LEFT JOIN storersodefault SOD WITH (NOLOCK) ON SOD.storerkey = ST.Storerkey
   LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.listname = 'SLABYREGION' AND C.short=SOD.destination
   LEFT OUTER JOIN Codelkup CLR (NOLOCK) ON (OH.Storerkey = CLR.Storerkey AND CLR.Code = 'HIDETTLCTN'
                                       AND CLR.Listname = 'REPORTCFG' AND CLR.Long = 'r_dw_ucc_carton_label_101' AND ISNULL(CLR.Short,'') <> 'N')
   LEFT OUTER JOIN Codelkup CLR1 (NOLOCK) ON (OH.Storerkey = CLR1.Storerkey AND CLR1.Code = 'HIDEUCCBARCODE'
                                       AND CLR1.Listname = 'REPORTCFG' AND CLR1.Long = 'r_dw_ucc_carton_label_101' AND ISNULL(CLR1.Short,'') <> 'N')
   JOIN #TMP_PSNO TPS ON TPS.Pickslipno = PH.PickSlipNo AND TPS.Storerkey = PH.StorerKey
   --WHERE PH.pickslipno = @c_getpickslipno
   --AND OH.StorerKey = @c_storerkey
   --WHERE PD.cartonno >= CASE WHEN @c_PrnByDropid = 'N' THEN CAST(@c_StartCartonNo as INT) ELSE PD.cartonno END
   --AND PD.cartonno <= CASE WHEN @c_PrnByDropid = 'N' THEN CAST(@c_EndCartonNo as INT) ELSE PD.cartonno END
   --where tps.DropID = @c_PickSlipNo 
   GROUP BY OH.Storerkey,OH.ExternOrderkey,OH.Loadkey,OH.Route,OH.Consigneekey,
          OH.Facility,OH.ExternPOKey,OH.C_Address1,OH.C_Address2,OH.C_Address3,
          OH.C_city,OH.C_state,OH.C_zip,tps.dropid , tps.refno2 ,--SUBSTRING(s.busr10,1,CHARINDEX('-',s.busr10) -1),
          --(SUBSTRING(s.busr10, 1, CHARINDEX('-', s.busr10) - 1)) + '-' + (SUBSTRING(s.busr10, CHARINDEX('-', s.busr10) + 1, 
          -- (CHARINDEX('-', s.busr10, CHARINDEX('-', s.busr10) + 1))-(CHARINDEX('-', s.busr10)+1))),
         TPS.model,
          PH.pickslipno,OH.C_company,tps.labelno,
          CASE WHEN ISNULL(CLR.Code,'') <> '' THEN 'Y' ELSE 'N' END,
          CASE WHEN ISNULL(CLR1.Code,'') <> '' THEN 'Y' ELSE 'N' END       
   order by PH.pickslipno ,OH.ExternOrderkey,tps.RefNo2 ,tps.Model

END
   INSERT INTO #TMP_LCartonLBL101Date (Storerkey,OrdExtOrdKey,ODD_Date,OAD_Date,ODD,OAD,SLA)
   SELECT DISTINCT OH.Storerkey,OH.ExternOrderkey,
                   CASE WHEN OH.StorerKey in ('Adidas') THEN CONVERT(DATETIME,OH.Userdefine03 ) 
                        ELSE OH.DeliveryDate END,OH.DeliveryDate,'','',
                   CASE WHEN ISNUMERIC(c.long) = 1 THEN CAST(C.long as INT) ELSE 0 END
   FROM ORDERS OH WITH (NOLOCK)
   --JOIN ORDERDETAIL OD WITH (NOLOCK) 
   JOIN PackHeader PH WITH (NOLOCK) ON PH.Orderkey = OH.Orderkey
  -- JOIN PACKDETAIL PD WITH (NOLOCK) ON PD.Pickslipno = PH.pickslipno
   LEFT JOIN STORER ST WITH (NOLOCK) ON ST.Storerkey = OH.Storerkey
  -- LEFT JOIN SKU S WITH (NOLOCK) ON S.storerkey = oh.Storerkey AND S.SKU = PD.SKU 
   LEFT JOIN storersodefault SOD WITH (NOLOCK) ON SOD.storerkey = ST.Storerkey
   LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.listname = 'SLABYREGION' AND C.short=SOD.destination
   JOIN #TMP_PSNO TPS ON TPS.Pickslipno = PH.PickSlipNo AND TPS.Storerkey = PH.StorerKey
   --where PH.pickslipno = @c_getpickslipno
   --AND OH.StorerKey = @c_storerkey

update #TMP_LCartonLBL101Date
SET ODD = CASE WHEN storerkey = 'Skechers' THEN CONVERT(NVARCHAR(11),ODD_date - SLA,106) ELSE CONVERT(NVARCHAR(11),ODD_Date,106) END
   ,OAD = CASE WHEN storerkey in ('NIKEMY','JDSPORTSMY','TBLMY') THEN CONVERT(NVARCHAR(11),ODD_date + SLA,106) ELSE CONVERT(NVARCHAR(11),OAD_Date,106) END

QUIT_SP:
   --SELECT * FROM #TMP_LCartonLBL101

   --SELECT * FROM #TMP_LCartonLBL101Date 

    SELECT DISTINCT a.loadkey,a.OrdExtOrdKey as externorderkey,a.TTLCtn as CtnCnt1,a.cartonno,a.DropID,a.SKUStyle as style,
           a.Storerkey,a.ttlqty as sizeqty,a.OHRoute,a.Consigneekey,a.Facility,a.ExternPOKey,a.ST_Address1,
           a.ST_Address2,a.ST_Address3,a.ST_City,a.ST_State,a.ST_Zip,a.RecGrp,a.Pickslipno
          ,REPLACE(b.ODD,' ' ,'-') AS ODD,REPLACE(b.OAD,' ' ,'-') AS OAD,a.ST_Company,a.labelno,a.HIDETTLCTN as hidettlctn
          ,a.HIDEUCCBARCODE AS Hideuccbarcode,a.PrnByDropID AS PrnByDropID
    FROM #TMP_LCartonLBL101 a
    JOIN #TMP_LCartonLBL101Date b on b.storerkey = a.storerkey and b.OrdExtOrdKey=a.OrdExtOrdKey 
    JOIN #TMP_PSNO TP ON TP.Pickslipno=a.Pickslipno AND TP.Storerkey=a.Storerkey
    --WHERE a.pickslipno = @c_getpickslipno
    where a.StorerKey = @c_storerkey
   -- AND a.cartonno >= CASE WHEN @c_PrnByDropid = 'N' THEN CAST(@c_StartCartonNo as INT) ELSE a.cartonno END 
    --AND a.cartonno <= CASE WHEN @c_PrnByDropid = 'N' THEN CAST(@c_EndCartonNo as INT) ELSE a.cartonno END 
    ORDER BY a.Pickslipno,a.OrdExtOrdKey,a.cartonno,a.SKUStyle

drop table #TMP_LCartonLBL101

drop table #TMP_LCartonLBL101Date  


END -- procedure

GO