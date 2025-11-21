SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Function:   isp_packing_list_invoice_001                             */  
/* Creation Date: 15-SEP-2023                                           */  
/* Copyright: Maersk                                                    */  
/* Written by: CSCHONG                                                  */  
/*                                                                      */  
/* Purpose:                                                             */  
/*        : WMS-23544 - [KR] GARMIN_Invoice Report_Data Window_New      */  
/*                                                                      */  
/* Called By:  r_dw_packing_list_invoice_001                            */  
/*                                                                      */  
/* PVCS Version: 1.1                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver.  Purposes                                */  
/* 15-SEP-2023  CSCHONG   1.0   DevOps Combine Script                   */
/************************************************************************/  
  
CREATE   PROC [dbo].[isp_packing_list_invoice_001] (  
                           @c_PickSlipNo   NVARCHAR( 10),       
                           @c_FromCartonNo NVARCHAR( 10),      
                           @c_ToCartonNo   NVARCHAR( 10)     
)  
AS                                   
BEGIN    
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF   
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @n_InvAmt             FLOAT  
         , @n_ShippingHandling   FLOAT  
         , @n_NoOfLine           INT  
         , @c_Country            NVARCHAR(10)
         , @c_Storerkey          NVARCHAR(15)  
         
   DECLARE  @n_MaxLineno       INT
          , @n_MaxId           INT
          , @n_MaxRec          INT
          , @n_CurrentRec      INT
  
   SET @n_MaxLineno = 25

  
   DECLARE @c_C01  NVARCHAR(250) = ''
         , @c_C02  NVARCHAR(250) = ''
         , @c_C04  NVARCHAR(250) = ''
         , @c_C05  NVARCHAR(250) = ''
         , @c_C06  NVARCHAR(250) = ''
         , @c_C07  NVARCHAR(250) = ''
         , @c_C08  NVARCHAR(250) = ''
         , @c_C09  NVARCHAR(250) = ''
         , @c_C03  NVARCHAR(250) = ''

      SELECT @c_Storerkey = OH.storerkey
      FROM ORDERS OH WITH (NOLOCK) 
      LEFT JOIN PackHeader PH WITH (NOLOCK)  ON PH.ORDERKEY = OH.ORDERKEY
      WHERE PH.PickSlipNo = @c_PickSlipNo


   
   SELECT @c_C01  = ISNULL(MAX(CASE WHEN C.Code ='C01'  THEN RTRIM(C.long) ELSE '' END),'') 
        , @c_C02  = ISNULL(MAX(CASE WHEN C.Code ='C02'  THEN RTRIM(C.long) ELSE '' END),'') 
        , @c_C03  = ISNULL(MAX(CASE WHEN C.Code ='C03'  THEN RTRIM(C.long) ELSE '' END),'') 
        , @c_C04  = ISNULL(MAX(CASE WHEN C.Code ='C04'  THEN RTRIM(C.long) ELSE '' END),'') 
        , @c_C05  = ISNULL(MAX(CASE WHEN C.Code ='C05'  THEN RTRIM(C.long) ELSE '' END),'') 
        , @c_C06  = ISNULL(MAX(CASE WHEN C.Code ='C06'  THEN RTRIM(C.long) ELSE '' END),'')  
        , @c_C07  = ISNULL(MAX(CASE WHEN C.Code ='C07'  THEN RTRIM(C.long) ELSE '' END),'')  
        , @c_C08  = ISNULL(MAX(CASE WHEN C.Code ='C08'  THEN RTRIM(C.long) ELSE '' END),'') 
        , @c_C09  = ISNULL(MAX(CASE WHEN C.Code ='C09'  THEN RTRIM(C.long) ELSE '' END),'') 
   FROM CODELKUP C WITH (NOLOCK) 
   WHERE C.listname = 'DNOTECONST' 
   AND C.notes = 'B2B' 
   AND C.storerkey = @c_Storerkey 
  
   CREATE TABLE #TMP_PLINV001   
            (  SeqNo                INT IDENTITY (1,1)  
            ,  RecGroup             INT   
            ,  FCAdd1               NVARCHAR(45)  
            ,  Sku                  NVARCHAR(20)  
            ,  Descr                NVARCHAR(250)  
            ,  CAdd                 NVARCHAR(250)  
            ,  Company              NVARCHAR(45)  
            ,  LABELNO              NVARCHAR(20)   
            ,  RowNo                INT  
            ,  Remark               NVARCHAR(80)  
            ,  TTLQty               INT   
            ,  C02                  NVARCHAR(250)      
            ,  C03                  NVARCHAR(250)      
            ,  C04                  NVARCHAR(250)   
            ,  C05                  NVARCHAR(250)                  
            ,  C06                  NVARCHAR(250)       
            ,  C07                  NVARCHAR(250)      
            ,  C08                  NVARCHAR(250)                  
            ,  C09                  NVARCHAR(250)       
            ,  C01                  NVARCHAR(250)         
            ,  Qty                  INT                
            )  
  
      INSERT INTO  #TMP_PLINV001
      (
          RecGroup,
          FCAdd1,
          Sku,
          Descr,
          CAdd,
          Company,
          LABELNO,
          RowNo,
          Remark,
          TTLQty,
          C02,
          C03,
          C04,
          C05,
          C06,
          C07,
          C08,
          C09,
          C01,
          Qty
      )
     
        
      SELECT 1 as recgroup  
            , FC.ADDRESS1  
            , PD.Sku  
            , Descr =  ISNULL(S.descr,'')  
            , ISNULL(OH.C_Address1,'')+ISNULL(OH.C_Address2,'')+ISNULL(OH.C_Address3,'')+ISNULL(OH.C_Address4,'')
            , Company    = ISNULL(OH.C_COMPANY,'') 
            , PD.LABELNO 
            , ROW_NUMBER () OVER(PARTITION BY PD.LABELNO ORDER BY PD.QTY DESC)
            , ''
            , (SELECT SUM(PD2.QTY) FROM PACKDETAIL(NOLOCK) PD2 WHERE PD2.STORERKEY = OH.STORERKEY AND PD2.LABELNO = PD.LABELNO)
            , C02 =  @c_C02 
            , C03 =  @c_C03 
            , C04 =  @c_C04 
            , C05 =  @c_C05 
            , C06 =  @c_C06                   
            , C07 =  @c_C07                
            , C08 =  @c_C08 
            , C09 =  @c_C09 
            , C01 =  @c_C01   
            , PD.QTY      
      FROM ORDERS OH WITH (NOLOCK) 
      JOIN FACILITY FC WITH (NOLOCK)  ON FC.FACILITY = OH.FACILITY
      LEFT JOIN PackHeader PH WITH (NOLOCK)  ON PH.ORDERKEY = OH.ORDERKEY
      LEFT JOIN PACKDETAIL PD WITH (NOLOCK)  ON PD.PICKSLIPNO = PH.PICKSLIPNO
      JOIN SKU S WITH (NOLOCK) ON S.STORERKEY = PD.STORERKEY
                               AND S.SKU = PD.SKU
      WHERE PH.PickSlipNo = @c_PickSlipNo
      AND PD.CartonNo >= CAST(@c_FromCartonNo AS INT) AND PD.CartonNo <= CAST(@c_ToCartonNo AS INT)
      AND OH.DocType = 'N'
  
    
   SELECT  RecGroup,
          FCAdd1,
          Sku,
          Descr,
          CAdd,
          Company,
          LABELNO,
          RowNo,
          Remark,
          TTLQty,
          C02,
          C03,
          C04,
          C05,
          C06,
          C07,
          C08,
          C09,
          C01,
          Qty                                                                                                        
   FROM #TMP_PLINV001 T_INV  

    
   DROP TABLE #TMP_PLINV001  
  
      
  
      GOTO QUIT  
    
   QUIT:  
END  

GO