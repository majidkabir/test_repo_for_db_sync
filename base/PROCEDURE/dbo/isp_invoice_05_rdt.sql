SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Function:   isp_invoice_05_rdt                                       */
/* Creation Date: 13-Jul-2017                                           */
/* Copyright: IDS                                                       */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose:                                                             */
/*        : WMS-13199 - CN HMCOS INVOICE REPORT                         */
/*                                                                      */
/* Called By:  r_dw_invoice_05_rdt                                      */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/************************************************************************/

CREATE PROC [dbo].[isp_invoice_05_rdt]  (
      @c_Orderkey       NVARCHAR(10) = ''
     ,@c_trackingno     NVARCHAR(30)  = ''
     ,@c_loadkey        NVARCHAR(20) = ''
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
          @c_storerkey         NVARCHAR(80),
          @n_continue          INT,
          @c_ExecStatements    NVARCHAR(4000),   
          @c_ExecArguments     NVARCHAR(4000)  

   SET @n_NoOfLine = 10

   CREATE TABLE #TMP_INVDET05rdt 
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
            )

     SET @c_SQLINSERT=N' INSERT INTO #TMP_INVDET05rdt ' +
                        '(Orderkey, Sku , Descr, trackingno , s_company , ' +                 
                        ' UnitPrice, PQty, s_shipname, s_address, C_contact1 , ' +                   
                        ' C_address1, C_address2 ,C_address3,C_address4,s_phone,' + 
                        ' c_phone1, UOQty, Currency,COO,  PACKTYPE ) '
     
     SET @c_SQLJOIN=N' SELECT DISTINCT top 10 OH.Orderkey,OD.Sku,Descr = ISNULL(s.descr,''''), ' +
                     ' trackingno = ISNULL(OH.TrackingNo,''''),s_company = ISNULL(C.Description,''''), ' +
                     ' UnitPrice = CONVERT(NVARCHAR(10),CONVERT(DECIMAL(8,2),OD.UnitPrice)) , ' +
                     ' PD.Qty , s_shipname = ISNULL(C.long,''''),s_address = ISNULL(C.notes,''''), ' +
                     ' OH.C_contact1,OH.C_Address1,OH.C_Address2,OH.C_Address3,OH.C_Address4, ' +  
                     ' s_phone    = ISNULL(C.UDF03,''''),OH.C_Phone1,UOQty  = ISNULL(C.UDF01,''''), ' +                   
                     ' Currency   = ISNULL(C.UDF02,''''), ' +
                     ' COO        = substring(LOTT.lottable02,PATINDEX(''%-%'', LOTT.lottable02)+1,5), ' +
                     ' PACKTYPE   =  ISNULL(C1.long,'''') ' + 
                     ' FROM ORDERDETAIL OD  WITH (NOLOCK) ' +
                     ' JOIN ORDERS      OH  WITH (NOLOCK) ON (OD.Orderkey = OH.Orderkey) ' +
                     ' JOIN PICKHEADER PIH WITH (NOLOCK) ON PIH.orderkey = OH.Orderkey ' +
                     ' JOIN SKU S WITH (NOLOCK) ON s.storerkey = OD.storerkey AND S.sku = OD.sku ' +
                     ' JOIN PACKDETAIL PD WITH (NOLOCK) ON PD.PickSlipNo = PIH.PickHeaderKey ' +
                     ' JOIN PackHeader PH WITH (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo ' +
                     ' JOIN PICKDETAIL PID WITH (NOLOCK) ON (PID.ORDERKEY = OD.ORDERKEY AND PID.SKU = OD.SKU AND PID.ORDERLINENUMBER = OD.ORDERLINENUMBER)' +
                     ' JOIN LOTATTRIBUTE LOTT WITH (NOLOCK) ON LOTT.lot = PID.lot ' +
                     ' LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.listname = ''cosdef'' AND c.code = ''1''  ' +
                     ' LEFT JOIN CODELKUP C1 WITH (NOLOCK) ON C1.listname = ''cosdef'' AND c1.code = CAST(PH.ctntyp1 as nvarchar(5)) ' 

    IF ISNULL(@c_Orderkey,'') <> '' AND ISNULL(@c_trackingno,'') <> '' AND ISNULL(@c_loadkey,'') = ''
    BEGIN 
          SET @c_SQLWHERE = N' WHERE OH.Orderkey =  @c_Orderkey ' + 
                             ' AND OH.Trackingno  = @c_trackingno '
   END
   ELSE IF ISNULL(@c_loadkey,'') <> ''
   BEGIN
        SET @c_SQLWHERE = N' WHERE OH.loadkey = @c_loadkey ' 
   END

    SET @c_SQLSORT = N' ORDER BY OH.Orderkey, ISNULL(OH.TrackingNo,'''') ' 
  
    SET @c_SQL = @c_SQLINSERT + CHAR(13) + @c_SQLJOIN + CHAR(13) + @c_SQLWHERE + CHAR(13) + @c_SQLSORT
 
      SET @c_ExecArguments = N' @c_Orderkey     NVARCHAR(10)'    
                          + ', @c_trackingno    NVARCHAR(30) '    
                          + ', @c_loadkey       NVARCHAR(20) '                  
                         
      EXEC sp_ExecuteSql     @c_SQL     
                           , @c_ExecArguments    
                           , @c_Orderkey  
                           , @c_trackingno    
                           , @c_loadkey
     

   QUIT:
      SELECT * FROM  #TMP_INVDET05rdt

       DROP TABLE #TMP_INVDET05rdt

END

GO