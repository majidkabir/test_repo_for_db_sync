SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_POD_18_rpt                                          */
/* Creation Date: 27-JUNE-2018                                          */
/* Copyright: LF Logistics                                              */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose: WMS-4994 - [CN] - CN WMS UCCAL POD                          */
/*        :                                                             */
/* Called By: isp_POD_18_rpt                                            */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_POD_18_rpt]
           @c_orderKey        NVARCHAR(30),
           @c_Consigneekey    NVARCHAR(45) = '',
		   @c_xiangshu        NVARCHAR(20) = '',
		   @c_jianshu         NVARCHAR(20) = '',
		   @c_Cube            NVARCHAR(10) = '' , 
		   @c_DMS             NVARCHAR(10) = '' ,
		   @c_transport       NVARCHAR(10) = '' 

AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT
         , @n_NoOfLine        INT
			 
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
      @c_SQLInsert       NVARCHAR(4000),
	  @c_storerkey       NVARCHAR(20)

Declare 
        @c_col01 NVARCHAR(120),
		@c_col02 NVARCHAR(120),
		@c_col03 NVARCHAR(120),
		@c_col04 NVARCHAR(120),
		@c_col05 NVARCHAR(120),
		@c_col06 NVARCHAR(120),
		@c_col07 NVARCHAR(120),
		@c_col08 NVARCHAR(120),
		@c_col09 NVARCHAR(120),
		@c_col10 NVARCHAR(120),
		@c_col11 NVARCHAR(120),
		@c_col12 NVARCHAR(120),
		@c_col13 NVARCHAR(120),
		@c_col14 NVARCHAR(120),
		@c_col15 NVARCHAR(120),
		@c_col16 NVARCHAR(120),
		@c_col17 NVARCHAR(120),
		@c_col18 NVARCHAR(120),
		@c_col19 NVARCHAR(120),
		@c_col20 NVARCHAR(120),
		@c_col21 NVARCHAR(120),
		@c_col22 NVARCHAR(120),
		@c_col23 NVARCHAR(120),
		@c_col24 NVARCHAR(120),
		@c_col25 NVARCHAR(120),
		@c_col26 NVARCHAR(120),
		@c_col27 NVARCHAR(120),
		@c_col28 NVARCHAR(120),
		@c_col29 NVARCHAR(120),
		@c_col30 NVARCHAR(120),
		@c_LabelName NVARCHAR(50),
		@c_LabelValue NVARCHAR(250)


   SET @n_StartTCnt = @@TRANCOUNT
   
   SET @n_NoOfLine = 16

   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END

   SET @c_storerkey = ''

   SELECT @c_storerkey = OH.Storerkey
   FROM ORDERS OH WITH (nolock)
   WHERE OH.Orderkey = @c_orderKey


   IF @c_storerkey = ''
   BEGIN
     SET @c_storerkey = '18412'
   END


    DECLARE CUR_LBL CURSOR LOCAL FORWARD_ONLY STATIC READ_ONLY FOR
    SELECT CL.code
         , CL.Notes
   FROM CODELKUP    CL WITH (NOLOCK) 
   WHERE (CL.ListName = 'PODHCODE'
          AND CL.storerkey = @c_storerkey)
   
   --WHERE OH. OrderKey = @c_orderKey 
   
   OPEN CUR_LBL

   FETCH NEXT FROM CUR_LBL INTO @c_LabelName
                             ,  @c_LabelValue


   WHILE @@FETCH_STATUS <> -1
   BEGIN  
   	  SET @c_col01   =  CASE WHEN @c_LabelName = 'C01'   THEN @c_LabelValue ELSE @c_col01   END 
      SET @c_col02   =  CASE WHEN @c_LabelName = 'C02'   THEN @c_LabelValue ELSE @c_col02   END 
      SET @c_col03   =  CASE WHEN @c_LabelName = 'C03'   THEN @c_LabelValue ELSE @c_col03   END
      SET @c_col04   =  CASE WHEN @c_LabelName = 'C04'   THEN @c_LabelValue ELSE @c_col04   END 
      SET @c_col05   =  CASE WHEN @c_LabelName = 'C05'   THEN @c_LabelValue ELSE @c_col05   END 
      SET @c_col06   =  CASE WHEN @c_LabelName = 'C06'   THEN @c_LabelValue ELSE @c_col06   END 
      SET @c_col07   =  CASE WHEN @c_LabelName = 'C07'   THEN @c_LabelValue ELSE @c_col07   END 
      SET @c_col08   =  CASE WHEN @c_LabelName = 'C08'   THEN @c_LabelValue ELSE @c_col08   END 
      SET @c_col09   =  CASE WHEN @c_LabelName = 'C09'   THEN @c_LabelValue ELSE @c_col09   END 
      SET @c_col10   =  CASE WHEN @c_LabelName = 'C10'   THEN @c_LabelValue ELSE @c_col10   END 

	  SET @c_col11   =  CASE WHEN @c_LabelName = 'C11'   THEN @c_LabelValue ELSE @c_col11   END 
      SET @c_col12   =  CASE WHEN @c_LabelName = 'C12'   THEN @c_LabelValue ELSE @c_col12   END 
      SET @c_col13   =  CASE WHEN @c_LabelName = 'C13'   THEN @c_LabelValue ELSE @c_col13   END
      SET @c_col14   =  CASE WHEN @c_LabelName = 'C14'   THEN @c_LabelValue ELSE @c_col14   END 
      SET @c_col15   =  CASE WHEN @c_LabelName = 'C15'   THEN @c_LabelValue ELSE @c_col15   END 
      SET @c_col16   =  CASE WHEN @c_LabelName = 'C16'   THEN @c_LabelValue ELSE @c_col16   END 
      SET @c_col17   =  CASE WHEN @c_LabelName = 'C17'   THEN @c_LabelValue ELSE @c_col17   END 
      SET @c_col18   =  CASE WHEN @c_LabelName = 'C18'   THEN @c_LabelValue ELSE @c_col18   END 
      SET @c_col19   =  CASE WHEN @c_LabelName = 'C19'   THEN @c_LabelValue ELSE @c_col19   END 
      SET @c_col20   =  CASE WHEN @c_LabelName = 'C20'   THEN @c_LabelValue ELSE @c_col20   END 

	  SET @c_col21   =  CASE WHEN @c_LabelName = 'C21'   THEN @c_LabelValue ELSE @c_col21   END 
      SET @c_col22   =  CASE WHEN @c_LabelName = 'C22'   THEN @c_LabelValue ELSE @c_col22   END 
      SET @c_col23   =  CASE WHEN @c_LabelName = 'C23'   THEN @c_LabelValue ELSE @c_col23   END
      SET @c_col24   =  CASE WHEN @c_LabelName = 'C24'   THEN @c_LabelValue ELSE @c_col24   END 
      SET @c_col25   =  CASE WHEN @c_LabelName = 'C25'   THEN @c_LabelValue ELSE @c_col25   END 
      SET @c_col26   =  CASE WHEN @c_LabelName = 'C26'   THEN @c_LabelValue ELSE @c_col26   END 
      SET @c_col27   =  CASE WHEN @c_LabelName = 'C27'   THEN @c_LabelValue ELSE @c_col27   END 
      SET @c_col28   =  CASE WHEN @c_LabelName = 'C28'   THEN @c_LabelValue ELSE @c_col28   END 
      SET @c_col29   =  CASE WHEN @c_LabelName = 'C29'   THEN @c_LabelValue ELSE @c_col29   END 
      SET @c_col30   =  CASE WHEN @c_LabelName = 'C30'   THEN @c_LabelValue ELSE @c_col30   END 
   
   
	FETCH NEXT FROM CUR_LBL INTO @c_LabelName
                              ,  @c_LabelValue

   END
   CLOSE CUR_LBL
   DEALLOCATE CUR_LBL

		IF LEN(@c_Consigneekey) > 0
        BEGIN

            SELECT '' AS C_Contact2 ,
				   '' AS ExtOrderkey ,
				   ST.Company AS C_Company ,
                   UPPER(@c_orderKey) AS OrderKey ,
                   LTRIM(RTRIM(ISNULL(ST.Address1, '')))
                   + LTRIM(RTRIM(ISNULL(ST.Address2, '')))
                   + LTRIM(RTRIM(ISNULL(ST.Address3, '')))
                   + LTRIM(RTRIM(ISNULL(ST.Address4, ''))) AS C_Address1 ,
				   ST.Storerkey AS ConsigneeKey ,
				   @c_DMS AS BuyerPO ,
				   '' AS 'OHNotes' ,
                   ST.Contact1 AS C_Contact1 ,
				   @c_jianshu AS Qty ,        --10
                   @c_xiangshu AS 'Pack_Qty' , 
                   '' AS 'mcube' ,
				   '' AS 'LoadKey' ,
                   Phone1 AS C_Phone1 ,
                   '' AS C_Phone2 ,
                   CONVERT(NVARCHAR(10), GETDATE(), 121) AS 'OBDATE' ,
                   ST.VAT AS STCompany ,
                   '' AS 'ST_Address' ,
                   '' AS ST_Phone1 , 
                   '' AS ST_Fax1 ,
                   '' AS 'DEL_Date' ,
                   @c_Cube AS 'CPack_Qty' ,  
                   '' AS 'OHUDF01' ,
                   '' AS StorerKey ,
                   '' AS Facility ,
                   '' AS 'BillToKey' ,
                   @c_transport AS InterMVehicle ,
                   CODELKUP.Short AS Trans_Type,
				   @c_col01 AS 'Col01',
				   @c_col02 AS 'Col02',
				   @c_col03 AS 'Col03',
				   @c_col04 AS 'Col04',
				   @c_col05 AS 'Col05',
				   @c_col06 AS 'Col06',
				   @c_col07 AS 'Col07',
				   @c_col08 AS 'Col08',
				   @c_col09 AS 'Col09',
				   @c_col10 AS 'Col10',
				   @c_col11 AS 'Col11',
				   @c_col12 AS 'Col12',
				   @c_col13 AS 'Col13',
				   @c_col14 AS 'Col14',
				   @c_col15 AS 'Col15',
				   @c_col16 AS 'Col16',
				   @c_col17 AS 'Col17',
				   @c_col18 AS 'Col18',
				   @c_col19 AS 'Col19',
				   @c_col20 AS 'Col20',
				   @c_col21 AS 'Col21',
				   @c_col22 AS 'Col22',
				   @c_col23 AS 'Col23',
				   @c_col24 AS 'Col24',
				   @c_col25 AS 'Col25',
				   @c_col26 AS 'Col26',
				   @c_col27 AS 'Col27',
				   @c_col28 AS 'Col28',
				   @c_col29 AS 'Col29',
				   @c_col30 AS 'Col30'
            FROM   STORER ST WITH ( NOLOCK )
                   LEFT JOIN CODELKUP WITH ( NOLOCK ) ON CODELKUP.Storerkey = ST.Storerkey
                                                           AND CODELKUP.LISTNAME = 'TRANSTYPE'
                                                           AND CODELKUP.Code = @c_transport
            WHERE  ST.StorerKey =  @c_Consigneekey
                   AND ST.VAT = 'UCCAL'

    END
    ELSE
    BEGIN

            SELECT   o.C_Contact2 ,
				     o.ExternOrderKey as ExtOrderkey,
                     o.C_Company as C_Company,
					 o.OrderKey ,
                     LTRIM(RTRIM(ISNULL(o.C_Address1, '')))
                     + LTRIM(RTRIM(ISNULL(o.C_Address2, '')))
                     + LTRIM(RTRIM(ISNULL(o.C_Address3, '')))
                     + LTRIM(RTRIM(ISNULL(o.C_Address4, ''))) AS 'C_Address1' ,
					 o.ConsigneeKey as ConsigneeKey,
					 o.BuyerPO ,
					 CAST(o.Notes AS NVARCHAR(255)) AS 'OHNotes' ,
                     o.C_contact1 ,
					 SUM(od.ShippedQty + od.QtyPicked) AS 'Qty' ,  --10
                     md.CtnCnt1 + md.CtnCnt2 + md.CtnCnt3 + md.CtnCnt4
                     + md.CtnCnt5 AS 'Pack_Qty' ,
                     md.[Cube] AS 'mcube',
					 o.LoadKey ,
                     o.C_Phone1 ,
                     o.C_Phone2 ,
                     CONVERT(NVARCHAR(10), o.EditDate, 121) AS 'OBDATE' ,
                     s.Company AS 'STCompany' ,
                     LTRIM(RTRIM(s.Address1)) + LTRIM(RTRIM(s.Address2)) AS 'ST_Address' ,
                     s.Phone1 AS ST_Phone1,
                     s.Fax1  AS ST_Fax1,
                     CONVERT(NVARCHAR(10), o.DeliveryDate, 121) AS 'DEL_Date' ,
					( ( md.CtnCnt1 + md.CtnCnt2 + md.CtnCnt3 + md.CtnCnt4
                     + md.CtnCnt5 ) * 0.1 ) as 'CPack_qty',
                     CONVERT(NVARCHAR(30), o.Notes) AS 'OHUDF01' ,
                     o.StorerKey ,
                     o.Facility ,
                     o.BillToKey AS 'BillToKey' ,
                     o.IntermodalVehicle AS 'InterMVehicle',
                     c.Short AS 'Trans_Type',
					 @c_col01 AS 'Col01',
					 @c_col02 AS 'Col02',
					 @c_col03 AS 'Col03',
					 @c_col04 AS 'Col04',
					 @c_col05 AS 'Col05',
					 @c_col06 AS 'Col06',
					 @c_col07 AS 'Col07',
					 @c_col08 AS 'Col08',
					 @c_col09 AS 'Col09',
					 @c_col10 AS 'Col10',
					 @c_col11 AS 'Col11',
					 @c_col12 AS 'Col12',
					 @c_col13 AS 'Col13',
					 @c_col14 AS 'Col14',
					 @c_col15 AS 'Col15',
					 @c_col16 AS 'Col16',
					 @c_col17 AS 'Col17',
					 @c_col18 AS 'Col18',
					 @c_col19 AS 'Col19',
					 @c_col20 AS 'Col20',
					 @c_col21 AS 'Col21',
					 @c_col22 AS 'Col22',
					 @c_col23 AS 'Col23',
					 @c_col24 AS 'Col24',
					 @c_col25 AS 'Col25',
					 @c_col26 AS 'Col26',
					 @c_col27 AS 'Col27',
					 @c_col28 AS 'Col28',
					 @c_col29 AS 'Col29',
					 @c_col30 AS 'Col30'
            FROM ORDERS o WITH ( NOLOCK )
            JOIN ORDERDETAIL od WITH ( NOLOCK ) ON od.OrderKey = o.OrderKey
            JOIN MBOLDETAIL md WITH ( NOLOCK ) ON md.OrderKey = o.OrderKey
            JOIN STORER s WITH ( NOLOCK ) ON s.StorerKey = o.StorerKey
            JOIN SKU sku WITH ( NOLOCK ) ON sku.StorerKey = od.StorerKey
                                                    AND sku.Sku = od.Sku
            LEFT JOIN CODELKUP c WITH ( NOLOCK ) ON c.Storerkey = o.StorerKey
                                                    AND c.LISTNAME = 'TRANSTYPE'
                                                    AND c.Code = o.IntermodalVehicle
            WHERE    o.OrderKey = @c_orderKey
            GROUP BY LTRIM(RTRIM(ISNULL(o.C_Address1, '')))
                     + LTRIM(RTRIM(ISNULL(o.C_Address2, '')))
                     + LTRIM(RTRIM(ISNULL(o.C_Address3, '')))
                     + LTRIM(RTRIM(ISNULL(o.C_Address4, ''))) ,
                     CONVERT(NVARCHAR(10), o.EditDate, 121) ,
                     CAST(o.Notes AS NVARCHAR(255)) ,
                     s.Company,
                     LTRIM(RTRIM(s.Address1)) + LTRIM(RTRIM(s.Address2)) ,
                     CONVERT(NVARCHAR(10), o.DeliveryDate, 121) ,
                     md.CtnCnt1 + md.CtnCnt2 + md.CtnCnt3 + md.CtnCnt4
                     + md.CtnCnt5 ,
                     CONVERT(NVARCHAR(30), o.Notes) ,
                     o.ExternOrderKey ,
                     o.ConsigneeKey ,
                     o.C_Company ,
                     o.C_contact1 ,
                     o.C_Contact2 ,
                     o.OrderKey ,
                     o.C_Phone1 ,
                     o.C_Phone2 ,
                     o.LoadKey ,
                     s.Phone1 ,
                     md.[Cube] ,
                     s.Fax1 ,
                     o.BuyerPO ,
                     o.StorerKey ,
                     o.Facility ,
                     o.BillToKey ,
                     o.IntermodalVehicle ,
                     c.Short
        END

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
END -- procedure

GO