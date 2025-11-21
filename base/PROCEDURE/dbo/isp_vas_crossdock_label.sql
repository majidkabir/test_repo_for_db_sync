SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: isp_VAS_crossdock_Label                            */  
/* Creation Date: 10-MAY-2022                                           */  
/* Copyright: LFL                                                       */  
/* Written by: CSCHONG                                                  */  
/*                                                                      */  
/* Purpose: WMS-19375 - WMS_19375_ AU_VAS Cross-Dock Label              */  
/*                                                                      */  
/* Called By: RDT                                                       */  
/*          : Datawindow - r_dw_VAS_crossdock_Label                     */  
/*                                                                      */  
/* GitLab Version: 1.0                                                  */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author   Ver. Purposes                                  */  
/* 10-MAY-2022  CHONGCS  1.0  DevOps Combine Script                     */  
/* 27-MAY-2022  SYCHUA   1.1  JSM-71657 - TRACKINGNO BARCODE FIX (SY01) */  
/* 21-NOV-2022  CHONGCS  1.2  WMS-21200 revised barcode logic (CS01)    */  
/************************************************************************/  
CREATE PROC [dbo].[isp_VAS_crossdock_Label] (  
      @c_LabelNo     NVARCHAR(20)  
  
)  
AS  
  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @n_StartTCnt          INT  
         , @n_Continue           INT = 1  
         , @b_Success            INT  
         , @n_Err                INT  
         , @c_Errmsg             NVARCHAR(255)  
  
 DECLARE @n_ctnsku     INT = 0  
        ,@c_sdescr     NVARCHAR(60)  
        ,@n_SeqNo      INT  
        ,@n_GetSeqNo   INT  
        ,@c_ColValue   NVARCHAR(500)  
        ,@c_L08        NVARCHAR(10)  
        ,@c_L16        NVARCHAR(10)  
        ,@c_L09        NVARCHAR(10)  
        ,@c_Notes      NVARCHAR(4000)  = ''  
        ,@n_Count      INT  
  
      CREATE TABLE #TMP_VASCD (  
                              Storerkey         NVARCHAR(20)  
                            , Labelno           NVARCHAR(20)  
                            , ExtOrdkey         NVARCHAR(50)  
                            , OHTrackingno      NVARCHAR(40)  
                            , CTTrackingno      NVARCHAR(40)  
                            , Shipperkey        NVARCHAR(15)  
                            , BuyerPO           NVARCHAR(40)  
                            , Notes             NVARCHAR(4000)  
                            , CCompany          NVARCHAR(45)  
                            , CAddress          NVARCHAR(250)  
                            , CZip              NVARCHAR(45)  
                            , MCompany          NVARCHAR(45)  
                            , MAddress          NVARCHAR(250)  
                            , STAddress         NVARCHAR(250)  
                            , Sdescr            NVARCHAR(60)  NULL  
                            , CountryBarcode    NVARCHAR(50)  NULL  
                            , TrackingBarcode   NVARCHAR(50)  NULL  
                            , L08               NVARCHAR(10)   NULL  
                            , L16               NVARCHAR(10)   NULL  
                            , L09               NVARCHAR(10)   NULL  
                            , CountryBarcodehr  NVARCHAR(50)  NULL    --CS01  
                            , TrackingBarcodehr NVARCHAR(50)  NULL    --CS01  
                  )  
  
   --Initializing Data  
   IF (@n_Continue = 1 OR @n_Continue = 2)  
   BEGIN  
  
      SELECT @n_ctnsku = COUNT(PD.sku)  
      FROM dbo.PackDetail PD WITH (NOLOCK)  
      WHERE PD.LabelNo = @c_labelno  
  
  
  --SELECT @n_ctnsku 'countsku'  
  
      IF @n_ctnsku=1  
      BEGIN  
          SELECT @c_sdescr = ISNULL(S.descr,'')  
          FROM PackDetail PD WITH (NOLOCK)  
          JOIN SKU S WITH (NOLOCK) ON s.StorerKey=PD.StorerKey AND S.sku = PD.SKU  
          WHERE PD.LabelNo = @c_labelno  
  
      END  
      ELSE  
      BEGIN  
          SET @c_sdescr ='MIXED'  
      END  
  
      INSERT INTO #TMP_VASCD  
                              (  
                                  Storerkey,  
                                  Labelno,  
                                  ExtOrdkey,  
                                  OHTrackingno,  
                                  CTTrackingno,  
                                  Shipperkey,  
                                  BuyerPO,  
                                  CCompany,  
                                  CAddress,  
                                  CZip,  
                                  MCompany,  
                                  MAddress,  
                                  STAddress,  
                                  Notes,  
                                  Sdescr,  
                                  CountryBarcode,  
                                  TrackingBarcode,  
                                  L08,  
                                  L16,  
                                  L09,  
                                  CountryBarcodehr,TrackingBarcodehr    --CS01   
                              )  
  
    SELECT DISTINCT TOP 1 O.StorerKey,PD.LabelNo,  
           O.externorderkey,  
           O.TrackingNo,ct.TrackingNo,  
           O.ShipperKey,O.UserDefine04,  
           SUBSTRING(O.C_Company,1,15),  
           ISNULL(o.C_Address1,'') + ',' + ISNULL(o.C_City,'') + ',' + ISNULL(o.c_state,'') + ',' + ISNULL(o.C_zip,'') + ',' + ISNULL(o.C_Country,''),  
           ISNULL(o.C_zip,''),SUBSTRING(ISNULL(o.M_Company,''),1,15),  
           ISNULL(o.M_Address1,'') + SPACE(1) + ISNULL(o.M_Address2,'') + SPACE(1) + ISNULL(o.M_City,'') + SPACE(1) + ISNULL(o.M_State,'') + SPACE(1) + ISNULL(o.M_Zip,''),  
           ISNULL(ST.Address1,'') + SPACE(1) + ISNULL(ST.Address2,'') + SPACE(1) + ISNULL(ST.City,'') + SPACE(1) + ISNULL(ST.State,'') + SPACE(1) + ISNULL(ST.Zip,''),  
           od.Notes ,@c_sdescr,'',  
           --'(00)'+ct.TrackingNo,   --SY01  
           '('+LEFT(ct.TrackingNo,2)+')'+RIGHT(ct.TrackingNo,LEN(ct.TrackingNo)-2),   --SY01  
           '','','','',LEFT(ct.TrackingNo,2)+RIGHT(ct.TrackingNo,LEN(ct.TrackingNo)-2) --CS01  
    FROM packdetail pd (nolock)  
  JOIN cartontrack ct (nolock) on pd.labelno = ct.labelno  
  JOIN orders o (nolock) on o.TrackingNo = ct.udf03  
  JOIN orderdetail od (nolock) on o.orderkey = od.orderkey  
    JOIN Storer ST (NOLOCK) ON ST.StorerKey=O.StorerKey  
  where PD.LabelNo = @c_labelno  
  
   END  
  
   --Main Process  
   IF (@n_Continue = 1 OR @n_Continue = 2)  
   BEGIN  
  
      SELECT @c_Notes = notes  
      FROM #TMP_VASCD  
      WHERE Labelno =@c_labelno  
  
  
         DECLARE CUR_SPLIT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT FDS.SeqNo, FDS.ColValue  
         FROM dbo.fnc_DelimSplit('|', @c_Notes) FDS  
  
         OPEN CUR_SPLIT  
  
         FETCH NEXT FROM CUR_SPLIT INTO @n_SeqNo, @c_ColValue  
  
         WHILE @@FETCH_STATUS <> -1  
         BEGIN  
  
            SET @n_GetSeqNo =0  
           -- SELECT @c_ColValue  
  
            IF @c_ColValue LIKE 'L~L08%'   --L~L04~900001~84706246  
            BEGIN  
                SET @n_GetSeqNo = @n_SeqNo  
               IF EXISTS ( SELECT COUNT(1)  
                           FROM dbo.fnc_DelimSplit('~', @c_ColValue)  
                           WHERE  SeqNo = @n_GetSeqNo)  
               BEGIN  
                  SELECT @c_L08 = RIGHT('0000'+ISNULL(ColValue,''),4)  
                  FROM dbo.fnc_DelimSplit('~', @c_ColValue)  
                  WHERE SeqNo = 4  
               END  
            END  
            ELSE IF @c_ColValue LIKE 'L~L16%'   --L~L06~00001~50.00  
            BEGIN  
               SET @n_GetSeqNo = @n_SeqNo  
               IF EXISTS ( SELECT COUNT(1)  
                      FROM dbo.fnc_DelimSplit('~', @c_ColValue)  
                           WHERE SeqNo = @n_GetSeqNo)  
               BEGIN  
                  SELECT @c_L16 = RIGHT('0000'+ISNULL(ColValue,''),4)  
                  FROM dbo.fnc_DelimSplit('~', @c_ColValue)  
                  WHERE SeqNo = 4  
               END  
            END  
            ELSE IF @c_ColValue LIKE 'L~L09%'   --L~L09~00001~2626  
            BEGIN  
               SET @n_GetSeqNo = @n_SeqNo  
               IF EXISTS ( SELECT COUNT(1)  
                           FROM dbo.fnc_DelimSplit('~', @c_ColValue)  
                           WHERE  SeqNo = @n_GetSeqNo)  
               BEGIN  
                  SELECT @c_L09 = RIGHT('0000'+ISNULL(ColValue,''),4)  
                  FROM dbo.fnc_DelimSplit('~', @c_ColValue)  
                  WHERE SeqNo = 4  
               END  
            END  
  
            FETCH NEXT FROM CUR_SPLIT INTO @n_SeqNo, @c_ColValue  
         END  
         CLOSE CUR_SPLIT  
         DEALLOCATE CUR_SPLIT  
  
         UPDATE #TMP_VASCD  
         SET L08 = @c_L08  
           , L16 = @c_L16  
           , L09 = @c_L09  
           ,CountryBarcode =  '(421)036'+CZip+'(90)'+ @c_L08  
           ,CountryBarcodehr =  N'Ê421036'+CZip+N'Ê90'+ @c_L08  
           ,TrackingBarcodehr = N'Ê' + TrackingBarcodehr  
        WHERE Labelno =@c_labelno  
  END  
   --Output Result back to DW  
   IF (@n_Continue = 1 OR @n_Continue = 2)  
   BEGIN  
      SELECT *  
      FROM #TMP_VASCD  
   END  
  
   --Clean up - Drop Temp table & Close, Deallocate Cursor  
  
   IF CURSOR_STATUS('LOCAL', 'CUR_SPLIT') IN (0 , 1)  
   BEGIN  
      CLOSE CUR_SPLIT  
      DEALLOCATE CUR_SPLIT  
   END  
END

GO