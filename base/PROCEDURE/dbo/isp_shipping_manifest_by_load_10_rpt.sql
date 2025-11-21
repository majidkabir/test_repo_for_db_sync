SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/
/* Stored Procedure: isp_shipping_manifest_by_load_10_rpt                */
/* Creation Date: 2018-06-22                                             */
/* Copyright: IDS                                                        */
/* Written by:                                                           */
/*                                                                       */
/* Purpose: WMS-5000 -CN_BrownForman_POD                                 */
/*                                                                       */
/* Called By: r_shipping_manifest_by_load_10_rpt                         */
/*                                                                       */
/* PVCS Version: 1.1                                                     */
/*                                                                       */
/* Version: 5.4                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author  Ver   Purposes                                   */
/*************************************************************************/
CREATE PROC [dbo].[isp_shipping_manifest_by_load_10_rpt]
         (  @c_storerkey  NVARCHAR(10),
			   @c_mbolkey    NVARCHAR(10),
			   @c_loadkey    NVARCHAR(10),
				@c_orderkey   NVARCHAR(10)
         )
         
         
         
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF  
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @n_NoOfLine       INT
          ,@c_getstorerkey   NVARCHAR(10)
          ,@c_getLoadkey     NVARCHAR(20)
          ,@c_getOrderkey    NVARCHAR(20)
          ,@c_getExtOrderkey NVARCHAR(20)

DECLARE 
      @c_SQL             NVARCHAR(4000),        
      @c_SQLSORT         NVARCHAR(4000),        
      @c_SQLJOIN         NVARCHAR(4000),
      @c_condition1      NVARCHAR(150) ,
      @c_condition2      NVARCHAR(150),
		@c_condition3      NVARCHAR(150),
      @c_SQLGroup        NVARCHAR(4000),
      @c_SQLOrdBy        NVARCHAR(150),
      @c_ExecArguments   NVARCHAR(4000),
      @c_SQLInsert       NVARCHAR(4000)
          
  CREATE TABLE #TMP_LoadOH10RPT(
          rowid           int identity(1,1),
          storerkey       NVARCHAR(20) NULL,
          loadkey         NVARCHAR(50) NULL,
          Orderkey        NVARCHAR(10) NULL)           
    
   CREATE TABLE #TMP_SMBLOAD10RPT (
          rowid           int identity(1,1),
          Orderkey        NVARCHAR(20)  NULL,
          mbolkey         NVARCHAR(50)  NULL,
          ST_logo         NVARCHAR(45)  NULL,
          SKU             NVARCHAR(20)  NULL,
          SDESCR          NVARCHAR(150) NULL,
          PUOM01          NVARCHAR(10)  NULL,
          PUOM03          NVARCHAR(10)  NULL,
          C_Address1      NVARCHAR(45)  NULL,
          ST_BCompany     NVARCHAR(50)  NULL,
          PQty            INT,
          CaseCnt         FLOAT, 
          ExtOrdKey       NVARCHAR(10) NULL,  
          ORDDate         DATETIME , 
          consigneekey    NVARCHAR(45) NULL,
          C_Address2      NVARCHAR(45) NULL,
          C_Address3      NVARCHAR(45) NULL,
          C_Contact1      NVARCHAR(45) NULL,
          C_Contact2      NVARCHAR(45) NULL,
          C_Phone1        NVARCHAR(45) NULL,
          C_Phone2        NVARCHAR(45) NULL,
          BillToKey       NVARCHAR(20) NULL,
          ST_notes1       NVARCHAR(150) NULL,
          ST_notes2       NVARCHAR(350) NULL,
          C_Company       NVARCHAR(45) NULL, 
          Facility        NVARCHAR(10) NULL,
          C_Address4      NVARCHAR(45) NULL,
          OHNotes         NVARCHAR(150) NULL,
          DeliveryDate    DATETIME ,
          STDNETWGT       FLOAT NULL,
          StdCube         FLOAT NULL,
          Storerkey       NVARCHAR(120) NULL 
          )       
   

	SET @c_condition1 = ''
	SET @c_condition2 = ''
	SET @c_condition3 = ''
	SET @c_SQLGroup = ''
	SET @c_SQLOrdBy = ''


   SET @c_SQLOrdBy = ' ORDER BY OH.loadkey,oh.orderkey'

	IF ISNULL(@c_loadkey,'') <> ''
	BEGIN 
	   SET @c_condition1 = ' And OH.loadkey = @c_loadkey '
	END

	IF ISNULL(@c_orderkey,'') <> ''
	BEGIN
	  SET @c_condition2 = ' And OH.Orderkey = @c_orderkey '
	END

	IF ISNULL(@c_mbolkey,'') <> ''
	BEGIN

	 SET @c_condition3 = ' AND OH.mbolkey = @c_mbolkey'

	END
           
    SET @c_SQLInsert = ''
    SET @c_SQLInsert ='INSERT INTO #TMP_LoadOH10RPT (storerkey, loadkey, Orderkey)' 
 
    SET @c_SQLJOIN = 'SELECT DISTINCT OH.storerkey,OH.loadkey,OH.Orderkey ' + CHAR(13) +
                     + ' FROM  ORDERS OH WITH (NOLOCK) '  + CHAR(13) +
							+ ' where OH.storerkey = @c_storerkey'

        SET @c_ExecArguments = N'@c_storerkey     NVARCHAR(10),'
                             + ' @c_mbolkey       NVARCHAR(10),' 
                             + ' @c_loadkey       NVARCHAR(20),'
                             + ' @c_orderkey      NVARCHAR(10)'
                          
      
		  	 
   SET @c_SQL = @c_SQLInsert + CHAR(13) + @c_SQLJOIN + CHAR(13) + @c_condition1 + CHAR(13) + @c_condition2 + CHAR(13) + @c_condition3 + CHAR(13) + @c_SQLOrdBy
    	
    	    EXEC sp_executesql   @c_SQL  
                       , @c_ExecArguments  
                       , @c_storerkey  
                       , @c_mbolkey
                       , @c_loadkey 
                       , @c_orderkey
   	
    DECLARE CUR_RESULT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT DISTINCT Storerkey,loadkey,Orderkey
   FROM   #TMP_LoadOH10RPT   
  
   OPEN CUR_RESULT   
     
   FETCH NEXT FROM CUR_RESULT INTO @c_getstorerkey,@c_getLoadkey,@c_getOrderkey

   WHILE @@FETCH_STATUS <> -1  
   BEGIN   	
   	
  INSERT INTO #TMP_SMBLOAD10RPT
  (
  	-- rowid -- this column value is auto-generated
  	       Orderkey,
          mbolkey,
          ST_logo,
          SKU,
          SDESCR,
          PUOM01,
          PUOM03,
          C_Address1,
          ST_BCompany,
          PQty,
          CaseCnt,
          ExtOrdKey,
          ORDDate,
          consigneekey,
          C_Address2,
          C_Address3,
          C_Contact1,
          C_Contact2,
          C_Phone1,
          C_Phone2,
          BillToKey,
          ST_notes1,
          ST_notes2,
          C_Company,
          Facility,
          C_Address4,
          OHNotes,
          DeliveryDate,
          STDNETWGT,
          StdCube,
          Storerkey
  )
   	SELECT DISTINCT oh.orderkey,
                    oh.mbolkey,
						  ST.logo,
						  PD.SKU,
						  S.Descr,
                    CASE WHEN P.PackUOM1 = 'CA' then N'箱' ELSE P.PackUOM1 END,
						  CASE WHEN P.Packuom3 =  'BOT' then N'瓶' ELSE P.Packuom3 END,
						  ISNULL(OH.C_Address1,'') as Add1 ,
						  ISNULL(ST.b_company,''),
						  sum(PD.qty) as PQTY,
						  P.casecnt,
						  OH.Externorderkey,
						  OH.Orderdate,
						  OH.consigneekey,
						  ISNULL(OH.C_Address2,'') as Add2 ,
						  ISNULL(OH.C_Address3,'') as Add3 ,
						  CASE WHEN ISNULL(SC.contact1,'') = '' THEN ISNULL(OH.c_contact1,'') ELSE ISNULL(SC.contact1,'') END, 
 						  CASE WHEN ISNULL(SC.contact2,'') = '' THEN ISNULL(OH.c_contact2,'') ELSE ISNULL(SC.contact1,'') END,
						  CASE WHEN ISNULL(SC.phone1,'') = '' THEN ISNULL(OH.C_phone1,'') ELSE ISNULL(SC.phone1,'') END, 
 						  CASE WHEN ISNULL(SC.phone2,'') = '' THEN ISNULL(OH.C_phone2,'') ELSE ISNULL(SC.phone2,'') END,	
		              OH.billtokey,ISNULL(ST.notes1,''), ISNULL(ST.notes2,''),OH.c_company,OH.facility,
						  ISNULL(OH.C_Address4,'') as Add4 ,ISNULL(OH.notes,'') as OHNoes ,OH.Deliverydate,
		              s.stdnetwgt,s.stdcube,oh.storerkey
				FROM  ORDERS OH WITH (NOLOCK) 
				join orderdetail OD WITH (NOLOCK) ON OD.orderkey = OH.Orderkey
				JOIN PICKDETAIL PD WITH (NOLOCK) ON PD.Orderkey = OD.Orderkey 
														  AND PD.sku = OD.sku AND PD.orderlinenumber=OD.Orderlinenumber
				JOIN Storer ST WITH (NOLOCK) ON ST.storerkey = OH.storerkey
				JOIN Storer SC WITH (NOLOCK) ON SC.Storerkey = OH.consigneekey
				JOIN SKU S WITH (NOLOCK) ON S.Storerkey = PD.Storerkey and S.SKU = PD.SKU
				JOIN PACK P WITH (NOLOCK) ON P.Packkey = S.Packkey
		     WHERE oh.StorerKey = @c_getstorerkey
			  AND oh.Orderkey = @c_getOrderkey
		GROUP BY oh.orderkey,
                    oh.mbolkey,
						  ST.logo,
						  PD.SKU,
						  S.Descr,
                    CASE WHEN P.PackUOM1 = 'CA' then N'箱' ELSE P.PackUOM1 END,
						  CASE WHEN P.Packuom3 =  'BOT' then N'瓶' ELSE P.Packuom3 END,
						  ISNULL(OH.C_Address1,''),
						  ISNULL(ST.b_company,''),
						  P.casecnt,
						  OH.Externorderkey,
						  OH.Orderdate,
						  OH.consigneekey,
						  ISNULL(OH.C_Address2,''),
						  ISNULL(OH.C_Address3,''),
						  CASE WHEN ISNULL(SC.contact1,'') = '' THEN ISNULL(OH.c_contact1,'') ELSE ISNULL(SC.contact1,'') END, 
 						  CASE WHEN ISNULL(SC.contact2,'') = '' THEN ISNULL(OH.c_contact2,'') ELSE ISNULL(SC.contact1,'') END,
						  CASE WHEN ISNULL(SC.phone1,'') = '' THEN ISNULL(OH.C_phone1,'') ELSE ISNULL(SC.phone1,'') END, 
 						  CASE WHEN ISNULL(SC.phone2,'') = '' THEN ISNULL(OH.C_phone2,'') ELSE ISNULL(SC.phone2,'') END,	
		              OH.billtokey,ISNULL(ST.notes1,''), ISNULL(ST.notes2,''),OH.c_company,OH.facility,
						  ISNULL(OH.C_Address4,'') ,ISNULL(OH.notes,'') ,OH.Deliverydate,
		              s.stdnetwgt,s.stdcube,oh.storerkey
ORDER BY oh.mbolkey,oh.orderkey,pd.sku

   	
   FETCH NEXT FROM CUR_RESULT INTO @c_getstorerkey,@c_getLoadkey,@c_getOrderkey 
   END   
   		
   SELECT
   	 Orderkey,
		 StdCube,
		 STDNETWGT,
       ST_BCompany,
       C_Address1,
		 C_Contact1,
       C_Contact2,
       C_Phone1,
       C_Phone2,
		 BillToKey,
		 ST_notes1,
		 ST_notes2,
		 C_Company,
		 PUOM01,
		 Facility,
       PUOM03,
		 Storerkey,
		 ST_logo,
       SKU,
		 ExtOrdKey,
       ORDDate,
		 PQty,
       consigneekey,
		 SDESCR,
       C_Address2,
       C_Address3,
       C_Address4,
       OHNotes,
       DeliveryDate,
       mbolkey,
       CaseCnt       
   FROM
   	#TMP_SMBLOAD10RPT 
    ORDER BY mbolkey,Orderkey,SKU
    
    QUIT_SP:
    
END


GO