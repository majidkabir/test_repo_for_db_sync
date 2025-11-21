SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Function:   isp_invoice_07_rdt                                       */  
/* Creation Date: 13-Jul-2020                                           */  
/* Copyright: IDS                                                       */  
/* Written by: CSCHONG                                                  */  
/*                                                                      */  
/* Purpose:                                                             */  
/*        : WMS-14044 - [CN]Fanatics_invoice report                     */  
/*                                                                      */  
/* Called By:  r_dw_invoice_07_rdt                                      */  
/*                                                                      */  
/* PVCS Version: 1.2                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver.  Purposes                                */  
/* 04-Jan-2021  WLChooi   1.1   WMS-15997 - Change column mapping (WL01)*/  
/* 05-Jan-2021  WLChooi   1.2   WMS-15997 - Add missing column (WL02)   */
/* 23-Feb-2021  ALiang	   1.3   INC1435896 - Bug Fix (AL01)             */
/************************************************************************/  
  
CREATE PROC [dbo].[isp_invoice_07_rdt]  (  
           @c_Storerkey         NVARCHAR(20),  
           @c_PickSlipNo        NVARCHAR(10),  
           @c_StartCartonNo     NVARCHAR(10) = '',  
           @c_EndCartonNo       NVARCHAR(10) = ''  
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
  
  DECLARE @c_SQL               NVARCHAR(4000),  
          @c_SQLSORT           NVARCHAR(4000),  
          @c_SQLJOIN           NVARCHAR(4000),  
          @c_SQLGRPBY          NVARCHAR(4000),  
          @c_SQLINSERT         NVARCHAR(4000),  
          @c_SQLWHERE          NVARCHAR(4000),  
        --  @c_storerkey         NVARCHAR(80),  
          @n_continue          INT,  
          @c_ExecStatements    NVARCHAR(4000),     
          @c_ExecArguments     NVARCHAR(4000)    
  
   SET @n_NoOfLine = 10  
  
   CREATE TABLE #TMP_INVDET07rdt   
            (  SeqNo                INT IDENTITY (1,1)  
            ,  Orderkey             NVARCHAR(10)  
            ,  C_contact1           NVARCHAR(45)  
            ,  trackingno           NVARCHAR(30)  
            ,  C_address1           NVARCHAR(45)  
            ,  C_address2           NVARCHAR(45)  
            ,  C_address3           NVARCHAR(45)  
            ,  C_address4           NVARCHAR(45)  
            ,  s_company            NVARCHAR(100)  
            ,  s_shipname           NVARCHAR(100)  
            ,  s_address            NVARCHAR(4000)  
            ,  s_phone              NVARCHAR(60)  
            ,  c_phone1             NVARCHAR(45)   
            ,  Sku                  NVARCHAR(20)  
            ,  Descr                NVARCHAR(250)    
            ,  UnitPrice            FLOAT  
            ,  UOQty                NVARCHAR(60)   
            ,  PQty                 INT             
            ,  Currency             NVARCHAR(60)    
            ,  COO                  NVARCHAR(60)     
            ,  PACKTYPE             NVARCHAR(60)   
            ,  Stdnetwgt            FLOAT  
            )  
  
     SET @c_SQLINSERT=N' INSERT INTO #TMP_INVDET07rdt ' +  
                        '(Orderkey, Sku , Descr, trackingno , s_company , ' +                   
                        ' UnitPrice, PQty, s_shipname, s_address, C_contact1 , ' +                     
                        ' C_address1, C_address2 ,C_address3,C_address4,s_phone,' +   
                        ' c_phone1, UOQty, Currency,COO,  PACKTYPE,Stdnetwgt ) '  
       
     SET @c_SQLJOIN=N' SELECT DISTINCT top 10 OH.Orderkey,OD.Sku,Descr = ISNULL(s.notes1,''''), ' +  
                     ' trackingno = ISNULL(OH.TrackingNo,''''),b_company = ISNULL(F.UserDefine01,''''), ' +   --WL02  
                     ' UnitPrice = CONVERT(NVARCHAR(10),CONVERT(DECIMAL(8,2),OD.UnitPrice)) , ' +  
                     ' PD.Qty , s_shipname = ISNULL(F.Contact1,''''),' +   --WL02  
                     ' s_address = ISNULL(F.Address3,''''), '+   --WL03 --ISNULL(B_Address1,'''')+space(1)+ISNULL(B_Address2,'''')+space(1)+ISNULL(B_Address3,'''')+space(1)+ISNULL(B_Address4,''''), ' +  
                     ' OH.C_contact1,ISNULL(OH.C_Address1,''''),ISNULL(OH.C_Address2,''''),ISNULL(OH.C_Address3,''''),ISNULL(OH.C_Address4,''''), ' +    
                     ' s_phone    = ISNULL(C.UDF03,''''),ISNULL(OH.C_Phone2,''''),UOQty  = ISNULL(C.UDF01,''''), ' +                     
                     ' Currency   = ISNULL(OH.M_Country,''''), ' +   --WL01  
                    -- ' COO        = PATINDEX(''%-%'', S.countryoforigin), ' +  
                     ' COO        = S.countryoforigin, ' +  
                     ' PACKTYPE   =  ISNULL(C.UDF04,''''), ' +   --WL02   
                     ' Stdnetwgt  = PD.Qty * S.Stdnetwgt ' +   --WL02  
                     ' FROM ORDERDETAIL OD  WITH (NOLOCK) ' +  
                     ' JOIN ORDERS      OH  WITH (NOLOCK) ON (OD.Orderkey = OH.Orderkey) ' +  
                     --' JOIN PICKHEADER PIH WITH (NOLOCK) ON PIH.orderkey = OH.Orderkey ' +  
                     ' JOIN SKU S WITH (NOLOCK) ON s.storerkey = OD.storerkey AND S.sku = OD.sku ' +
					 ' JOIN PackHeader PH WITH (NOLOCK) ON OH.Orderkey = PH.Orderkey' +  --AL01
					 ' JOIN PACKDETAIL PD WITH (NOLOCK) ON (PD.PickSlipNo = PH.PickSlipNo and  OD.SKU = PD.SKU)' +	--AL01				 
					 --' JOIN PACKDETAIL PD WITH (NOLOCK) ON PD.PickSlipNo = PIH.PickHeaderKey ' +  
                     --' JOIN PackHeader PH WITH (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo ' +  
                     ' JOIN PICKDETAIL PID WITH (NOLOCK) ON (PID.ORDERKEY = OD.ORDERKEY AND PID.SKU = OD.SKU AND PID.ORDERLINENUMBER = OD.ORDERLINENUMBER)' +  
                     ' JOIN LOTATTRIBUTE LOTT WITH (NOLOCK) ON LOTT.lot = PID.lot ' +  
                     ' LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.listname = ''18891def'' AND c.code = ''1''  ' +  
                     ' LEFT JOIN CODELKUP C1 WITH (NOLOCK) ON C1.listname = ''18891def'' AND c1.code = CAST(PH.ctntyp1 as nvarchar(5)) ' +  
                     ' JOIN Facility F WITH (NOLOCK) ON F.Facility = OH.Facility' +   --WL02  
                     ' WHERE PH.Pickslipno = @c_Pickslipno '   
  
      SET @c_SQLSORT = N' ORDER BY OH.Orderkey, ISNULL(OH.TrackingNo,'''') '   
    
      SET @c_SQL = @c_SQLINSERT + CHAR(13) + @c_SQLJOIN + CHAR(13) + @c_SQLSORT  
   
      SET @c_ExecArguments = N' @c_Pickslipno     NVARCHAR(10)'                     
                           
      EXEC sp_ExecuteSql     @c_SQL       
                           , @c_ExecArguments      
                           , @c_Pickslipno    
  
   QUIT:  
      SELECT * FROM  #TMP_INVDET07rdt  
  
      DROP TABLE #TMP_INVDET07rdt  
  
END  

GO