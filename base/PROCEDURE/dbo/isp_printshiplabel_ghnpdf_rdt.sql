SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_PrintshipLabel_ghnpdf_RDT                           */
/* Creation Date: 07-JAN-2022                                           */
/* Copyright: LF Logistics                                              */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose: WMS-18618 - VN-ADIDAS-B2C-GHN_ShippingLabel_Creation        */
/*        :                                                             */
/* Called By: r_dw_print_shiplabel_ghnpdf_rdt                           */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 07-JAN-2022 CSCHONG  1.1   Devops Scripts combine                    */
/* 14-MAR-2022 CSCHONG  1.2   WMS-18618 revised print logic (CS01)      */
/************************************************************************/
CREATE   PROC [dbo].[isp_PrintshipLabel_ghnpdf_RDT]
            @c_OrderKey     NVARCHAR(20)  

AS  
BEGIN  
   SET NOCOUNT ON   
   SET ANSI_NULLS OFF   
   SET QUOTED_IDENTIFIER OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF     

   DECLARE    
           @n_StartTCnt       INT  
         , @n_Continue        INT  
   
         , @c_moneysymbol    NVARCHAR(5)   
         , @n_TTLUnitPrice   DECIMAL(10,2)
         , @c_footerRemarks  NVARCHAR(500) 
         , @n_MaxLine         INT 
         , @n_maxctn          INT
         , @c_PmtTerm         NVARCHAR(10)
         , @n_CurCtn          INT
         , @c_COD             NVARCHAR(30)
         , @c_CODtitle        NVARCHAR(30)
         , @c_extordkeycarton NVARCHAR(60) = ''
        -- , @c_orderkey        NVARCHAR(20) = ''
         , @c_storerkey       NVARCHAR(20)
         , @c_Carton          NVARCHAR(20) = ''
         , @n_OrdDelNotes     DECIMAL(10,2)
  
   SET @n_StartTCnt = @@TRANCOUNT  
   SET @n_Continue = 1  
            
   SET @n_Maxline = 17    
   SET @c_moneysymbol = N'VND'   
   SET @n_CurCtn = 1
   SET @c_PmtTerm = ''
   SET @n_maxctn = 1
   SET @c_COD = '' 
   SET @n_TTLUnitPrice = 0.00
   SET @c_CODtitle = 'COD:'
   SET @c_footerRemarks = N'KÃ½ tÃªn vÃ  xÃ¡c nháº­n nguyÃªn váº¹n'
  
  
  CREATE TABLE #PRNSHIPINVRPT  
      (  c_citystate       NVARCHAR(90)    
      ,  Carton            NVARCHAR(20)   
      ,  ST_contact1       NVARCHAR(45)  
      ,  ExternOrderkey    NVARCHAR(50)   
      ,  CAddress          NVARCHAR(200) 
      ,  C_phone1          NVARCHAR(45) NULL        
      ,  ST_phone2         NVARCHAR(45)  
      ,  Orderkey          NVARCHAR(10)      
      ,  ExtOrdkeyCarton   NVARCHAR(60)     
      ,  Storerkey         NVARCHAR(15) 
      ,  COD               NVARCHAR(50)   
      ,  C_Company         NVARCHAR(45) 
      ,  ST_notes2         NVARCHAR(4000)    
      ,  OHNotes           NVARCHAR(4000)
      ,  Trackingno        NVARCHAR(40)
      ,  ST_notes1          NVARCHAR(4000)    
      ,  CartonNo          INT
      ,  FooterNotes        NVARCHAR(500)  
)
  
   --IF EXISTS (SELECT 1 FROM ORDERS oh WITH (NOLOCK) WHERE oh.OrderKey = @c_orderkey AND oh.Status >= '5' AND oh.TrackingNo <> '')     --CS01
   IF EXISTS (SELECT 1 FROM ORDERS oh WITH (NOLOCK) WHERE oh.OrderKey = @c_orderkey AND oh.DocType = 'E' AND oh.TrackingNo <> '')      --CS01
   BEGIN
   SELECT @c_storerkey = oh.StorerKey
         --,@c_orderkey = oh.Orderkey
         ,@c_PmtTerm = oh.PmtTerm
         ,@n_OrdDelNotes = CASE WHEN ISNUMERIC(oh.DeliveryNote) = 1 THEN CAST(oh.DeliveryNote AS DECIMAL(10,2)) ELSE 0.00 END
   FROM Orders oh (NOLOCK)
   WHERE oh.OrderKey=@c_orderkey


   --SELECT @c_storerkey '@c_storerkey', @c_orderkey '@c_orderkey', @c_PmtTerm '@c_PmtTerm'

   SELECT @n_maxctn = MAX(pif.cartonno)
   FROM dbo.PackInfo pif WITH (NOLOCK)
   JOIN Packheader ph (NOLOCK) ON ph.PickSlipNo=pif.PickSlipNo
   WHERE ph.orderkey  = @c_orderkey

   --SELECT @n_maxctn '@n_maxctn'
   --PRINT '1'
   IF @c_PmtTerm = 'COD'
   BEGIN

     SELECT @n_TTLUnitPrice = SUM((OD.QTYPicked + OD.ShippedQTY)  * OD.Unitprice) + @n_OrdDelNotes
     FROM dbo.ORDERDETAIL OD WITH (NOLOCK) 
     WHERE OD.OrderKey = @c_orderkey


   SET @c_COD = @c_CODtitle + CAST(FORMAT(@n_TTLUnitPrice, 'N','en-us') AS NVARCHAR(20)) + SPACE(2) + @c_moneysymbol   --CS01

   --SELECT @c_COD '@c_COD'

   END
   ELSE
   BEGIN
       SET @c_COD = ''
   END

   --SELECT @c_COD '@c_COD'


   --WHILE (@n_CurCtn <=@n_maxctn)-- >= 1
   --BEGIN
   --    IF @n_CurCtn = @n_maxctn 
   --    BEGIN
   --      SET @c_Carton = CAST (@n_CurCtn AS  NVARCHAR(10)) + '/' + CAST(@n_maxctn AS NVARCHAR(10))
   --    END
   --    ELSE
   --    BEGIN
   --      SET @c_Carton = CAST (@n_CurCtn AS  NVARCHAR(10)) + '/...'
   --    END
         SET @c_extordkeycarton = ''--@c_externorderkey + '.' + CAST (@n_CurCtn AS  NVARCHAR(10))
        --SELECT @c_Carton '@c_Carton' ,@c_extordkeycarton '@c_extordkeycarton'

      INSERT INTO #PRNSHIPINVRPT
      (
          c_citystate,
          Carton,
          ST_contact1,
          ExternOrderkey,
          CAddress,
          C_phone1,
          ST_phone2,
          Orderkey,
          ExtOrdkeyCarton,
          Storerkey,
          COD,
          C_Company,
          ST_notes1,
          ST_notes2,
          OHNotes,
          Trackingno,
          CartonNo,
          FooterNotes
      )
     SELECT
          ISNULL(oh.c_city,'') + SPACE(1) + ISNULL(OH.C_State,'') , -- c_citystate - nvarchar(45)
          @c_Carton, -- Carton - nvarchar(20)
          ST.contact1, -- ST_contact1 - nvarchar(45)
          OH.UserDefine05, -- ExternOrderkey - nvarchar(50)
          ISNULL(oh.C_Address1,'') + SPACE(1) + ISNULL(oh.C_Address2,'') + SPACE(1) +ISNULL(oh.C_Address3,'') 
          + SPACE(1) +ISNULL(oh.C_Address4,''), -- C_Address - nvarchar(200)
          Oh.C_Phone1, -- C_phone1 - nvarchar(45)
          ST.Phone2, -- ST_phone2 - nvarchar(45)
          OH.OrderKey, -- Orderkey - nvarchar(10)
          @c_extordkeycarton, -- ExtOrdkeyCarton - nvarchar(60)
          OH.StorerKey, -- Storerkey - nvarchar(15)
          @c_COD, -- COD - nvarchar(50)
          OH.C_Company, -- C_Company - nvarchar(45)
          ISNULL(ST.Notes1,''), -- OHNotes2 - nvarchar(4000)
          ISNULL(ST.Notes2,''), -- ST_notes2 - nvarchar(4000)
          ISNULL(OH.Notes,''), -- OHNotes - nvarchar(4000)
          OH.TrackingNo, -- Trackingno - nvarchar(40)
          @n_CurCtn ,
          @c_footerRemarks   -- FooterNotes - nvarchar(500)
       FROM dbo.ORDERS OH WITH (NOLOCK)
       JOIN dbo.STORER ST WITH (NOLOCK) ON St.StorerKey=OH.StorerKey 
       WHERE OH.StorerKey =@c_storerkey
       AND OH.OrderKey = @c_orderkey

    
    -- SET @n_CurCtn = @n_CurCtn + 1
     --SET @n_maxctn = @n_maxctn - 1
  -- END
     SELECT * FROM #PRNSHIPINVRPT
     ORDER BY ExternOrderkey,CartonNo
   END
   ELSE
   BEGIN
      GOTO QUIT
   END
  
QUIT:  
  
  IF OBJECT_ID('tempdb..#PRNSHIPINVRPT') IS NOT NULL
   DROP TABLE #PRNSHIPINVRPT

END -- procedure  


GO