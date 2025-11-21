SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  isp_UCC_Carton_Label_66_RDT                        */
/* Creation Date: 11-SEP-2017                                           */
/* Copyright: IDS                                                       */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose:  WMS-2873-CN_PVH_Report_CartonLabel                         */
/*                                                                      */
/* Input Parameters: Storerkey ,PickSlipNo, CartonNoStart, CartonNoEnd  */
/*                                                                      */
/* Output Parameters:                                                   */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Called By:  r_dw_ucc_carton_label_66_RDT                             */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 16-JAN-2017  CSCHONG  1.0  WMS-3781-revised report logic (CS01)      */
/* 23-Apr-2018  CSCHONG  1.1  WMS-4507 - add new field (CS02)           */
/* 05-JUN-2018  MLAM     1.2  Handle mulit carton printing (ML01)       */
/* 06-JUN-2018  CSCHONG  1.3 WMS-4507 add new field (CS03)              */
/* 28-JUN-2018  CSCHONG  1.4 Peformance tunning (CS04)                  */
/* 02-JUL-2018  Ting     1.5 Peformance tunning (Ting01)                */
/* 06-DEC-2018  CSCHONG  1.6 WMS-7121-revised field logic (CS05)        */
/* 02-DEC-2019  WLChooi  1.7 WMS-11295 - Add DropID column, control by  */
/*                           ReportCFG (WL01)                           */
/************************************************************************/

CREATE PROC [dbo].[isp_UCC_Carton_Label_66_RDT] (
         @c_Storerkey      NVARCHAR(10)
      ,  @c_PickSlipNo     NVARCHAR(20)
      ,  @c_StartCartonNo  NVARCHAR(20)
      ,  @c_EndCartonNo    NVARCHAR(20)
)
AS
BEGIN

   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_Ordtype           NVARCHAR(20)
         , @c_ordgrp          NVARCHAR(20)
         , @c_Ordkey          NVARCHAR(20)
         , @c_loadkey         NVARCHAR(20)
         , @c_ORDAdd1         NVARCHAR(45)
         , @c_ORDAdd2         NVARCHAR(45)
         , @c_ORDAdd3         NVARCHAR(45)
         , @c_OrdConsigneekey NVARCHAR(20)
         , @c_ExtOrdKey       NVARCHAR(20)
         , @c_OHUDF01         NVARCHAR(30)
         , @c_OHDELNotes      NVARCHAR(50)
         , @c_billtoKey       NVARCHAR(50)
         , @c_OHType          NVARCHAR(10)
         , @c_CCompany        NVARCHAR(45)
         , @c_CCity           NVARCHAR(45)
         , @c_CCountry        NVARCHAR(30)
         , @c_FAdd1           NVARCHAR(45)
         , @c_FAdd2           NVARCHAR(45)
         , @c_FAdd3           NVARCHAR(45)
         , @c_FFacility       NVARCHAR(5)
         , @c_FFDESCR         NVARCHAR(100)
         , @c_OHCVAT          NVARCHAR(30)
         , @c_labelno         NVARCHAR(20)
         , @c_CTL             NVARCHAR(30)
         , @c_getloadkey      NVARCHAR(50)
         , @c_CountryR        NVARCHAR(30)
         , @c_barcodelblno    NVARCHAR(50)
         , @c_BarcodeDesc     NVARCHAR(80)
         , @c_consoOrd        NVARCHAR(1)
         , @c_Brand           NVARCHAR(5)            --CS01
         , @c_showfield       NVARCHAR(1)            --CS02
         , @c_SPRemarks       NVARCHAR(250)          --CS02
         , @c_CLong           NVARCHAR(80)           --CS02
         , @n_CartonNo        INT                    --ML01
         , @c_toloc           NVARCHAR(10)           --CS03
         , @c_SpecialNote1    NVARCHAR(5)            --CS03
         , @c_SpecialNote2    NVARCHAR(5)            --CS03
         , @c_SpecialNote3    NVARCHAR(5)            --CS03
         , @c_SpecialNote4    NVARCHAR(5)            --CS03
         , @c_DropID          NVARCHAR(50)           --WL01
         , @c_ShowDropID      NVARCHAR(1)            --WL01

   CREATE TABLE #TMP_UCCCTNLBL66 (
      rowid           int NOT NULL IDENTITY(1,1) PRIMARY KEY ,  --(Ting01)
      Pickslipno      NVARCHAR(20)  NULL,
      consigneekey    NVARCHAR(20)  NULL,
      SHIPAdd1        NVARCHAR(45)  NULL,
      SHIPAdd2        NVARCHAR(45)  NULL,
      SHIPAdd3        NVARCHAR(45)  NULL,
      CTL             NVARCHAR(30)  NULL,
      FROMAdd1        NVARCHAR(45)  NULL,
      FROMCITY        NVARCHAR(45)  NULL,
      FROMCountry     NVARCHAR(30)  NULL,
      FROMAdd2        NVARCHAR(45)  NULL,
      LabelNo         NVARCHAR(20)  NULL,
      FROMAdd3        NVARCHAR(45)  NULL,
      FFacility       NVARCHAR(5)   NULL,
      FDESCR          NVARCHAR(100) NULL,
      OHUDF01         NVARCHAR(30)  NULL,
      OHDELNotes      NVARCHAR(50)  NULL,
      Billtokey       NVARCHAR(50)  NULL,
      OHCVAT          NVARCHAR(30)  NULL,
      OHTYPE          NVARCHAR(10)  NULL,
      FROMCompany     NVARCHAR(45)  NULL,
      loadkey         NVARCHAR(50)  NULL,
      CountryR        NVARCHAR(35)  NULL,
      Barcode_LblNO   NVARCHAR(100) NULL,
      BarcodeDescr    NVARCHAR(80)  NULL,
      Brand           NVARCHAR(5)   NULL,                      --CS01
      CLong           NVARCHAR(80)  NULL,                      --CS02
      SPRemarks       NVARCHAR(250) NULL,                      --CS02
      Showfield       NVARCHAR(1)   NULL,                      --CS02
      Toloc           NVARCHAR(20)  NULL,                      --CS03
      SpecialNote1    NVARCHAR(5)   NULL,                      --CS03 
      SpecialNote2    NVARCHAR(5)   NULL,                      --CS03
      SpecialNote3    NVARCHAR(5)   NULL,                      --CS03 
      SpecialNote4    NVARCHAR(5)   NULL,                      --CS03    
      DropID          NVARCHAR(50)  NULL                       --WL01                                                      
   )

-- ML01 Start
   DECLARE CUR_CARTONNO CURSOR LOCAL FAST_FORWARD READ_ONLY FOR --(Ting01)
   SELECT CartonNo
     FROM PACKDETAIL WITH (NOLOCK)
    WHERE PickslipNo = @c_PickSlipNo
      AND CartonNo BETWEEN CAST(@c_StartcartonNo AS INT) AND CAST(@c_EndcartonNo AS INT)
    GROUP BY CartonNo 
    ORDER BY CartonNo

   OPEN CUR_CARTONNO

   WHILE 1=1
   BEGIN
      FETCH NEXT FROM CUR_CARTONNO
       INTO @n_CartonNo

      IF @@FETCH_STATUS<>0
         BREAK
-- ML01 End

       --  SET @c_StorerKey = ''
      SET @c_ordgrp = ''
      SET @c_Ordkey = ''
      SET @c_loadkey = ''
      SET @c_labelno = ''
      SET @c_Ordtype = ''
      SET @c_barcodelblno = ''
      SET @c_consoOrd = 'N'
      SET @c_BarcodeDesc = '(00)' + Space(2) + 'Serial Shipping Container '
      SET @c_Brand = ''                                                     --CS01
      SET @c_SPRemarks = ''                                                 --CS02
      SET @c_CLong  = ''                                                    --CS02
      SET @c_DropID = ''                                                    --WL01

      SELECT TOP 1 @c_Ordkey  = PH.OrderKey
                  ,@c_loadkey = PH.LoadKey
                  ,@c_labelno = PD.LabelNo
           -- ,@c_Brand = ISNULL(S.busr6,'')                              --(CS04)
      FROM  PACKHEADER  PH WITH (NOLOCK)
      JOIN  PACKDETAIL  PD WITH (NOLOCK) on PD.pickslipno = PH.pickslipno
    --  JOIN SKU S WITH (NOLOCK) ON S.StorerKey = PD.StorerKey AND S.Sku = PD.SKU
      WHERE PH.Pickslipno = @c_PickSlipNo
-- ML01         AND   PD.CartonNo BETWEEN CAST(@c_StartcartonNo AS INT) AND CAST(@c_EndcartonNo AS INT)
      AND   PD.CartonNo = @n_CartonNo                                    --ML01
    --  ORDER BY ISNULL(S.busr6,'')                                         --(CS04)

      --CS02 Start
      SET @c_showfield  = 'N'
      SET @c_ShowDropID = 'N'   --WL01

      SELECT @c_showfield  = ISNULL(MAX(CASE WHEN Code = 'ShowField'  THEN 'Y' ELSE 'N' END),'N')
           , @c_ShowDropID = ISNULL(MAX(CASE WHEN Code = 'ShowDropID' THEN 'Y' ELSE 'N' END),'N')    --WL01
      FROM CODELKUP WITH (NOLOCK)
      WHERE ListName = 'REPORTCFG'
      AND   Storerkey= @c_Storerkey
      AND   Long = 'r_dw_ucc_carton_label_66_RDT'
      AND   ISNULL(Short,'') <> 'N'
      --CS02 END

      IF @c_Ordkey = ''
      BEGIN

         SET @c_consoOrd = 'Y'

         SELECT TOP 1 @c_Ordkey = ORD.Orderkey
         FROM ORDERS ORD WITH (NOLOCK)
         WHERE ORD.LoadKey = @c_loadkey
         ORDER BY ORD.Orderkey

      END

      SELECT TOP 1 @c_ordgrp  = ORD.OrderGroup
                  ,@c_OrdConsigneekey =  ISNULL(ORD.ConsigneeKey,'')
                  ,@c_ORDAdd1   = ISNULL(ORD.C_Address1,'')
                  ,@c_ORDAdd2   = ISNULL(ORD.C_Address2,'')
                  ,@c_ORDAdd3   = ISNULL(ORD.C_Address3,'')
                  ,@c_CTL       = CASE WHEN C.udf01 = 'R' THEN @c_loadkey ELSE ISNULL(ORD.ExternOrderkey,'') END
                  ,@c_FAdd1     = ISNULL(F.Address1,'')
                  ,@c_CCity     = ISNULL(ORD.C_CITY,'')
                  ,@c_CCountry  = ISNULL(ORD.C_state,'')
                  ,@c_FAdd2     = ISNULL(F.Address2,'')
                  ,@c_FAdd3     = ISNULL(F.Address3,'')
                  ,@c_FFacility = ISNULL(F.Facility,'')
                  ,@c_FFDESCR   = ISNULL(F.descr,'')
                  ,@c_OHUDF01   = CASE WHEN C.udf01 = 'R' THEN ISNULL(ORD.UserDefine01,'') ELSE '' END
                  ,@c_OHDELNotes= CASE WHEN C.udf01 = 'W' THEN ISNULL(ORD.UserDefine03,'') ELSE '' END
                  ,@c_billtoKey = CASE WHEN C.udf01 = 'W' THEN ISNULL(ORD.BillToKey,'')
                                   ELSE CASE WHEN C.udf01 = 'R' AND ISNULL(ORD.b_Country,'') ='CN' THEN 'CNRETAIL'
                                   ELSE ISNULL(ORD.b_Country,'') END END
                  ,@c_OHCVAT    = CASE WHEN C.udf01 = 'R' THEN ISNULL(ST.[Secondary],'') ELSE '' END
                  ,@c_OHType    = CASE WHEN C.udf01 = 'R' THEN ISNULL(ORD.[type],'') 
				                       WHEN C.Code = 'RW' THEN ISNULL(ORD.[type],'')  ELSE ' ' END       --CS05
                  ,@c_CCompany  = ISNULL(ORD.C_Company,'')
                  ,@c_getloadkey= @c_loadkey
                  ,@c_CountryR  = ISNULL(ORD.C_Country,'')
                  ,@c_CLong     = CASE WHEN @c_showfield='Y' THEN ISNULL(C1.Long,'X') ELSE '' END                                                 --CS02
                  ,@c_SPRemarks = CASE WHEN C.udf01 = 'R' AND ORD.UserDefine05 NOT IN ('24','25','26') THEN ISNULL(ST.notes1,'') ELSE ' ' END,
                  --CS03 Start
                   @c_toloc = CASE WHEN @c_showfield='Y' AND @c_ShowDropID = 'N' THEN ISNULL(PD.toLoc,'') ELSE '' END,   --WL01
                   @c_SpecialNote1 = CASE WHEN @c_showfield='Y' AND ORD.BillToKey = 'TWRETAIL' 
                                AND (ORD.Type = 'R' or (ORD.Type = 'L' and OD.UserDefine06 like 'L%R')) THEN '1' ELSE '' END ,
                   @c_SpecialNote2 = CASE WHEN @c_showfield='Y' AND ORD.BillToKey = 'TWRETAIL' and ORD.Type = 'R' and ORD.BuyerPO = 'BRA' THEN '2' ELSE '' END,
                   @c_SpecialNote3 = CASE WHEN @c_showfield='Y' AND ORD.BillToKey = 'TWRETAIL' and ORD.Type = 'L' 
                                    and OD.UserDefine06 like 'L%R' and ORD.BuyerPO <> 'BRA' THEN '3' ELSE '' END,
                   @c_SpecialNote4 = CASE WHEN @c_showfield='Y' AND ORD.BillToKey = 'TWRETAIL' and ORD.Type = 'L' 
                                  and OD.UserDefine06 like 'L%R' and ORD.BuyerPO = 'BRA' Then '4' ELSE '' END           
                  --CS03 end
						,@c_Brand = ISNULL(Sku.busr6,'')                                                           --(CS04)
      FROM ORDERS ORD (NOLOCK)
      JOIN Orderdetail OD WITH (NOLOCK) ON OD.OrderKey = ORD.OrderKey 
      JOIN SKU Sku WITH (NOLOCK) ON Sku.StorerKey = OD.StorerKey AND Sku.Sku = OD.SKU                --(CS04)
      LEFT JOIN STORER ST WITH(NOLOCK) ON ST.storerkey = 'PVH' + ORD.ConsigneeKey
      JOIN FACILITY F WITH (NOLOCK) ON F.facility = ORD.Facility
      LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.LISTNAME = 'ORDERGROUP' AND C.Code = ORD.OrderGroup AND C.Storerkey=ORD.storerkey  --(Ting01)
      LEFT JOIN STORER S WITH (NOLOCK) ON S.CustomerGroupCode = C.Storerkey
      --CS02 Start
      LEFT JOIN CODELKUP C1 WITH (NOLOCK) ON C1.LISTNAME='PVHPXLBL' AND C1.Storerkey=ORD.StorerKey AND C1.Code=ORD.BillToKey
      --CS02 End
      --CS03 Start
      LEFT JOIN PACKHEADER PH WITH (NOLOCK) ON PH.LoadKey=ord.LoadKey
      LEFT JOIN PACKDETAIL PAD WITH (NOLOCK) ON pad.PickSlipNo = ph.PickSlipNo
      LEFT JOIN PICKDETAIL AS PD WITH (NOLOCK) ON PD.CaseID=PAD.LabelNo and OD.sku = PD.Sku AND OD.OrderKey = PD.OrderKey 
      --CS03 End
      WHERE ORD.Orderkey = @c_Ordkey
		AND   PAD.cartonno = @n_CartonNo

      --SET @c_barcodelblno = master.dbo.fnc_GetCharASCII(212) + @c_labelno
      SET @c_barcodelblno = '(00)' + @c_labelno
      --SET @c_barcodelblno = '(' + substring(@c_labelno,1,2) + ')' + SPACE(1) +SUBSTRING(@c_labelno,3,1) + SPACE(1) + SUBSTRING(@c_labelno,4,7)
      --                       + SPACE(1) + SUBSTRING(@c_labelno,11,9) + SPACE(1) + SUBSTRING(@c_labelno,20,1)

      --WL01 Start
      SELECT @c_DropID  = CASE WHEN @c_showfield='N' AND @c_ShowDropID = 'Y' THEN 'Drop ID: ' + ISNULL(MAX(PD.DropID),'') ELSE '' END
      FROM  PACKHEADER  PH WITH (NOLOCK)
      JOIN  PACKDETAIL  PD WITH (NOLOCK) on PD.pickslipno = PH.pickslipno
      WHERE PH.Pickslipno = @c_PickSlipNo
      AND   PD.CartonNo = @n_CartonNo 
      --WL01 End

      INSERT INTO #TMP_UCCCTNLBL66(Pickslipno,consigneekey,SHIPAdd1,SHIPAdd2,SHIPAdd3,CTL,
                                    FROMAdd1,FROMCITY,FROMCountry,FROMAdd2,LabelNo,FROMAdd3,
                                    FFacility,FDESCR,OHUDF01,OHDELNotes,Billtokey,OHCVAT,OHTYPE,FROMCompany,loadkey,
                                    CountryR,Barcode_LblNO,BarcodeDescr,Brand,CLong,
                                    SPRemarks, Showfield,Toloc, SpecialNote1,
                                    SpecialNote2, SpecialNote3,SpecialNote4,DropID)                                  --CS02   --CS03   --WL01
      VALUES(@c_PickSlipNo,@c_OrdConsigneekey,@c_ORDAdd1,@c_ORDAdd2,@c_ORDAdd3,@c_CTL,@c_FAdd1,@c_CCity,@c_CCountry,@c_FAdd2,@c_labelno,
             @c_FAdd3,@c_FFacility,@c_FFDESCR,@c_OHUDF01,@c_OHDELNotes,@c_billtoKey,@c_OHCVAT,@c_OHType,@c_CCompany,@c_getloadkey
            ,@c_CountryR ,@c_barcodelblno,@c_BarcodeDesc,@c_Brand,@c_CLong,@c_SPRemarks,@c_showfield,@c_toloc
            ,@c_SpecialNote1,@c_SpecialNote2,@c_SpecialNote3,@c_SpecialNote4                   --CS02  --CS03
            ,@c_DropID) --WL01
   -- ML01 Start
   END

   CLOSE CUR_CARTONNO
   DEALLOCATE CUR_CARTONNO
   -- ML01 End

   SELECT Pickslipno,consigneekey,SHIPAdd1,SHIPAdd2,SHIPAdd3,CTL,
			 FROMAdd1,FROMCITY,FROMCountry,FROMAdd2,LabelNo,FROMAdd3,
			 FFacility,FDESCR,OHUDF01,OHDELNotes,Billtokey,OHCVAT,OHTYPE,FROMCompany,loadkey,
			 CountryR,Barcode_LblNO,BarcodeDescr,Brand,CLong,
			 SPRemarks, Showfield ,Toloc, SpecialNote1,
			 SpecialNote2, SpecialNote3, SpecialNote4,                               --CS02  --Cs03
          DropID --WL01
   FROM #TMP_UCCCTNLBL66

END

GO