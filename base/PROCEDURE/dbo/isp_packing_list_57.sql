SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Stored Procedure: isp_Packing_List_57                                */    
/* Creation Date: 15-Jan-2019                                           */    
/* Copyright: IDS                                                       */    
/* Written by: WLCHOOI                                                  */    
/*                                                                      */    
/* Purpose: WMS-7655 - [SG] JUUL Invoice                                */    
/*                                                                      */    
/*                                                                      */    
/* Called By: report dw = r_dw_Packing_List_57                          */    
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
    
CREATE PROC [dbo].[isp_Packing_List_57] (    
   @c_MBOLKey NVARCHAR(21)     
)     
AS     
BEGIN    
   SET NOCOUNT ON    
  -- SET ANSI_WARNINGS OFF    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET ANSI_DEFAULTS OFF    

   CREATE TABLE #TEMP_PACKLIST57(
      ST_B_Company     NVARCHAR(45) NULL
	  ,ST_B_Address1    NVARCHAR(45) NULL
	  ,ST_B_Address2    NVARCHAR(45) NULL
	  ,ST_B_Address3    NVARCHAR(45) NULL
	  ,ST_B_Address4    NVARCHAR(45) NULL
	  ,ST_B_City        NVARCHAR(45) NULL
	  ,ST_B_State       NVARCHAR(45) NULL
	  ,ST_B_Zip         NVARCHAR(45) NULL
	  ,ST_B_Country     NVARCHAR(45) NULL
	  ,InvoiceNo        NVARCHAR(45) NULL
	  ,ORD_C_Company    NVARCHAR(45) NULL
	  ,ORD_C_Address1   NVARCHAR(45) NULL
	  ,ORD_C_Address2   NVARCHAR(45) NULL
	  ,ORD_C_Address3   NVARCHAR(45) NULL
	  ,ORD_C_Address4   NVARCHAR(45) NULL
	  ,ORD_C_City       NVARCHAR(45) NULL
	  ,ORD_C_State      NVARCHAR(45) NULL
	  ,ORD_C_Zip        NVARCHAR(45) NULL
	  ,ORD_C_Contact1   NVARCHAR(45) NULL
	  ,ORD_C_Phone1     NVARCHAR(45) NULL
	  ,ORD_B_Company    NVARCHAR(45) NULL
	  ,ORD_B_Address1   NVARCHAR(45) NULL
	  ,ORD_B_Address2   NVARCHAR(45) NULL
	  ,ORD_B_Address3   NVARCHAR(45) NULL
	  ,ORD_B_Address4   NVARCHAR(45) NULL
	  ,ORD_B_City       NVARCHAR(45) NULL
	  ,ORD_B_State      NVARCHAR(45) NULL
	  ,ORD_B_Zip        NVARCHAR(45) NULL
	  ,ORD_B_Country    NVARCHAR(45) NULL
	  ,ORD_B_Contact1   NVARCHAR(45) NULL
	  ,ORD_B_Phone1     NVARCHAR(45) NULL
	  ,ST_Country       NVARCHAR(45) NULL
	  ,ORD_C_Country    NVARCHAR(45) NULL
	  ,ORD_IncoTerm     NVARCHAR(45) NULL
	  ,ORD_IntVehicle   NVARCHAR(45) NULL
	  ,ORD_PmtTerm      NVARCHAR(45) NULL
	  ,DropID           NVARCHAR(45) NULL
	  ,Sku              NVARCHAR(45) NULL
	  ,DESCR            NVARCHAR(200) NULL
	  ,QTY              INT NULL
	  ,Casecnt          INT NULL
	  ,NetWgt           FLOAT NULL
	  ,GrossWgt         FLOAT NULL
	  ,Orderkey         NVARCHAR(20) NULL

   )

   DECLARE @c_orderkey NVARCHAR(20)
			,@c_dropID NVARCHAR(45)
			,@c_sku    NVARCHAR(45)
			,@n_continue INT

   SET @c_orderkey = ''
   SET @c_dropID = ''
   SET @c_sku = ''
   SET @n_continue = 1

   IF(@n_continue = 1 OR @n_continue = 2)
   BEGIN
   INSERT INTO #TEMP_PACKLIST57(ST_B_Company,ST_B_Address1,ST_B_Address2,ST_B_Address3,ST_B_Address4,ST_B_City,ST_B_State,ST_B_Zip
            ,ST_B_Country,InvoiceNo,ORD_C_Company,ORD_C_Address1,ORD_C_Address2,ORD_C_Address3,ORD_C_Address4,ORD_C_City,ORD_C_State 
	        ,ORD_C_Zip,ORD_C_Contact1,ORD_C_Phone1,ORD_B_Company,ORD_B_Address1,ORD_B_Address2,ORD_B_Address3,ORD_B_Address4,ORD_B_City     
	        ,ORD_B_State,ORD_B_Zip,ORD_B_Country,ORD_B_Contact1,ORD_B_Phone1,ST_Country,ORD_C_Country,ORD_IncoTerm,ORD_IntVehicle 
	        ,ORD_PmtTerm,DropID,Sku,DESCR,QTY,Casecnt,NetWgt,GrossWgt,Orderkey)            

	SELECT  TRIM(ISNULL(ST.B_Company,''))
					,TRIM(ISNULL(ST.B_Address1,''))
					,TRIM(ISNULL(ST.B_Address2,''))
					,TRIM(ISNULL(ST.B_Address3,''))
					,TRIM(ISNULL(ST.B_Address4,''))
					,TRIM(ISNULL(ST.B_City,''))
					,TRIM(ISNULL(ST.B_State,''))
					,TRIM(ISNULL(ST.B_Zip,''))
					,TRIM(ISNULL(ST.B_Country,''))
					,TRIM(ISNULL(ORD.InvoiceNo,''))
					,TRIM(ISNULL(ORD.C_Company,''))
					,TRIM(ISNULL(ORD.C_Address1,''))
					,TRIM(ISNULL(ORD.C_Address2,''))
					,TRIM(ISNULL(ORD.C_Address3,''))
					,TRIM(ISNULL(ORD.C_Address4,''))
					,TRIM(ISNULL(ORD.C_City,''))
					,TRIM(ISNULL(ORD.C_State,''))
					,TRIM(ISNULL(ORD.C_Zip,''))
					,TRIM(ISNULL(ORD.C_Contact1,''))
					,TRIM(ISNULL(ORD.C_Phone1,''))
					,TRIM(ISNULL(ORD.B_Company,''))
					,TRIM(ISNULL(ORD.B_Address1,''))
					,TRIM(ISNULL(ORD.B_Address2,''))
					,TRIM(ISNULL(ORD.B_Address3,''))
					,TRIM(ISNULL(ORD.B_Address4,''))
					,TRIM(ISNULL(ORD.B_City,''))
					,TRIM(ISNULL(ORD.B_State,''))
					,TRIM(ISNULL(ORD.B_Zip,''))
					,TRIM(ISNULL(ORD.B_Country,''))
					,TRIM(ISNULL(ORD.B_Contact1,''))
					,TRIM(ISNULL(ORD.B_Phone1,''))
					,TRIM(ISNULL(ST.Country,''))
					,TRIM(ISNULL(ORD.C_Country,''))
					,TRIM(ISNULL(ORD.IncoTerm,''))
					,TRIM(ISNULL(ORD.IntermodalVehicle,''))
					,TRIM(ISNULL(ORD.PmtTerm,''))
					,PID.DropID
					,TRIM(PID.Sku)
					,TRIM(SKU.DESCR)
					,SUM(PID.Qty)
					,Pack.Casecnt
					,SKU.Netwgt
					,SKU.Grosswgt
					,ORD.Orderkey
	FROM MBOLDETAIL MD (NOLOCK)
	JOIN ORDERS ORD (NOLOCK) ON MD.ORDERKEY = ORD.ORDERKEY
	JOIN ORDERDETAIL ORDET (NOLOCK) ON ORDET.ORDERKEY = ORD.ORDERKEY 
	JOIN STORER ST (NOLOCK) ON ST.STORERKEY = ORD.STORERKEY
	JOIN PICKDETAIL PID (NOLOCK) ON PID.ORDERKEY = ORDET.ORDERKEY AND PID.OrderLineNumber = ORDET.OrderLineNumber
									AND PID.Sku = ORDET.Sku
	JOIN SKU (NOLOCK) ON SKU.SKU = ORDET.SKU AND ORD.StorerKey = SKU.StorerKey
	JOIN PACK (NOLOCK) ON SKU.PACKKEY = PACK.PACKKEY
	WHERE MD.MbolKey = @c_MBOLKey
	GROUP BY TRIM(ISNULL(ST.B_Company,''))
					,TRIM(ISNULL(ST.B_Address1,''))
					,TRIM(ISNULL(ST.B_Address2,''))
					,TRIM(ISNULL(ST.B_Address3,''))
					,TRIM(ISNULL(ST.B_Address4,''))
					,TRIM(ISNULL(ST.B_City,''))
					,TRIM(ISNULL(ST.B_State,''))
					,TRIM(ISNULL(ST.B_Zip,''))
					,TRIM(ISNULL(ST.B_Country,''))
					,TRIM(ISNULL(ORD.InvoiceNo,''))
					,TRIM(ISNULL(ORD.C_Company,''))
					,TRIM(ISNULL(ORD.C_Address1,''))
					,TRIM(ISNULL(ORD.C_Address2,''))
					,TRIM(ISNULL(ORD.C_Address3,''))
					,TRIM(ISNULL(ORD.C_Address4,''))
					,TRIM(ISNULL(ORD.C_City,''))
					,TRIM(ISNULL(ORD.C_State,''))
					,TRIM(ISNULL(ORD.C_Zip,''))
					,TRIM(ISNULL(ORD.C_Contact1,''))
					,TRIM(ISNULL(ORD.C_Phone1,''))
					,TRIM(ISNULL(ORD.B_Company,''))
					,TRIM(ISNULL(ORD.B_Address1,''))
					,TRIM(ISNULL(ORD.B_Address2,''))
					,TRIM(ISNULL(ORD.B_Address3,''))
					,TRIM(ISNULL(ORD.B_Address4,''))
					,TRIM(ISNULL(ORD.B_City,''))
					,TRIM(ISNULL(ORD.B_State,''))
					,TRIM(ISNULL(ORD.B_Zip,''))
					,TRIM(ISNULL(ORD.B_Country,''))
					,TRIM(ISNULL(ORD.B_Contact1,''))
					,TRIM(ISNULL(ORD.B_Phone1,''))
					,TRIM(ISNULL(ST.Country,''))
					,TRIM(ISNULL(ORD.C_Country,''))
					,TRIM(ISNULL(ORD.IncoTerm,''))
					,TRIM(ISNULL(ORD.IntermodalVehicle,''))
					,TRIM(ISNULL(ORD.PmtTerm,''))
					,PID.DropID
					,TRIM(PID.Sku)
					,TRIM(SKU.DESCR)
					,Pack.Casecnt
					,SKU.Netwgt
					,SKU.Grosswgt
					,ORD.Orderkey
			ORDER BY ORD.Orderkey asc
	END

	--IF(@n_continue = 1 OR @n_continue = 2)
 --   BEGIN
	--	DECLARE CUR_QTY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
	--	SELECT Orderkey, DropID, SKU
	--	FROM #TEMP_PACKLIST55
	--	ORDER BY ORDERKEY

	--	OPEN CUR_QTY
	--	FETCH NEXT FROM CUR_QTY INTO @c_orderkey, @c_dropID, @c_sku
	--	WHILE @@FETCH_STATUS=0
	--	BEGIN
		
	--	UPDATE #TEMP_PACKLIST55
	--	SET QTY = (SELECT SUM(QTY) FROM PICKDETAIL (NOLOCK) WHERE Orderkey = @c_orderkey AND DropID = @c_dropID AND SKU = @c_sku)
	--	WHERE Orderkey = @c_orderkey AND DropID = @c_dropID AND SKU = @c_sku

	--	FETCH NEXT FROM CUR_QTY INTO @c_orderkey, @c_dropID, @c_sku
	--	END
	--END

	SELECT * FROM #TEMP_PACKLIST57 order by Orderkey

QUIT:    
END    


GO