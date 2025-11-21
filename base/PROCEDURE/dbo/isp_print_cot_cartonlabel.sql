SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_Print_COT_CartonLabel                          */
/* Creation Date: 21-Aug-2008                                           */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: To print Outbound Label for SG Cotton On. (SOS114411)       */
/*                                                                      */
/* Called By: PB - Loadplan & Report Modules                            */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Purposes                                      */
/* 28-Jan-2019  TLTING_ext 1.1  enlarge externorderkey field length      */
/************************************************************************/

CREATE PROC [dbo].[isp_Print_COT_CartonLabel] (
       @cLoadKey       NVARCHAR(10) = '', 
       @cPickSlipNo    NVARCHAR(10) = '', 
       @nNoOfCartons  int = 1
)
AS
BEGIN
   SET NOCOUNT ON			-- SQL 2005 Standard
   SET QUOTED_IDENTIFIER OFF	
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF        

   DECLARE @n_continue    int,
           @c_errmsg      NVARCHAR(255),
           @b_success     int,
           @n_err         int, 
           @b_debug       int

   DECLARE @n_cnt int

   DECLARE @t_Result Table (
         Cartons             int,
         Total_Cartons       int,
         PickSlipNo           NVARCHAR(10),
         ExternOrderKey       NVARCHAR(50),   --tlting_ext
		 ConsigneeKey		  NVARCHAR(15),
		 C_Company            NVARCHAR(45),	
		 C_Address1           NVARCHAR(45),	
		 C_Address2           NVARCHAR(45),	
		 C_Address3           NVARCHAR(45),	
		 C_Address4           NVARCHAR(45),	
		 DeliveryDate         NVARCHAR(12),
       company              NVARCHAR(45),
		 address1             NVARCHAR(45),
		 address2             NVARCHAR(45),
		 phone1               NVARCHAR(18),
		 phone2               NVARCHAR(18),
       rowid                int IDENTITY(1,1)   )


   IF @b_debug = 1
   BEGIN
   
      SELECT    DISTINCT @n_cnt,
				@nNoOfCartons,
				PH.PickHeaderKey, 
				O.ExternOrderkey,
				O.ConsigneeKey,
				O.C_Company,	
				O.C_Address1,	
				O.C_Address2,
				O.C_Address3,	
				O.C_Address4,
				O.DeliveryDate,	
				Storer.company,
				Storer.address1,
				Storer.address2,
				Storer.phone1,
				Storer.phone2
      		FROM Orders O WITH (NOLOCK) 
      			    JOIN Storer WITH (NOLOCK) on (storer.storerkey = O.storerkey)
      			    JOIN OrderDetail OD WITH (NOLOCK) on (O.orderkey = OD.orderkey) 
      			    JOIN SKU WITH (NOLOCK) on (OD.storerkey = SKU.storerkey
      			                      AND OD.sku = SKU.sku ) 
      			    LEFT OUTER Join CodeLKUP CL WITH (NOLOCK) on (SKU.IVAS = CL.code)
                   JOIN PickHeader PH WITH (NOLOCK) ON PH.OrderKey = O.OrderKey 
      		WHERE ( ISNULL(dbo.fnc_RTRIM(@cPickSlipNo), '') = '' OR PH.PickHeaderKey = @cPickSlipNo) 
      		and   ( ISNULL(dbo.fnc_RTRIM(@cLoadKey), '')    = '' OR O.loadkey = @cLoadKey )
            ORDER BY O.ExternOrderkey

   END

   Set @n_cnt = 1
   While @n_cnt <=  @nNoOfCartons 		
   BEGIN
      INSERT INTO @t_Result (Cartons,		Total_Cartons,      
            PickSlipNo,				ExternOrderKey,		ConsigneeKey,
			C_Company,				C_Address1,			C_Address2,				
			C_Address3,				C_Address4,			DeliveryDate,			
            company,      			address1,			address2,
			phone1,      			phone2)
      SELECT DISTINCT @n_cnt,
				@nNoOfCartons,
				PH.PickHeaderKey, 
				O.ExternOrderkey,
				O.ConsigneeKey,
				O.C_Company,	
				O.C_Address1,	
				O.C_Address2,
				O.C_Address3,	
				O.C_Address4,
				DATENAME(day, O.DeliveryDate)+ ' '+ Left(DATENAME(month, O.DeliveryDate),3) + ' ' + DATENAME(year, O.DeliveryDate) DeliveryDate,		
				Storer.company,
				Storer.address1,
				Storer.address2,
				Storer.phone1,
				Storer.phone2
   		FROM Orders O WITH (NOLOCK) 
   			    JOIN Storer WITH (NOLOCK) on (storer.storerkey = O.storerkey)
   			    JOIN OrderDetail OD WITH (NOLOCK) on (O.orderkey = OD.orderkey) 
   			    JOIN SKU WITH (NOLOCK) on (OD.storerkey = SKU.storerkey
   			                      AND OD.sku = SKU.sku ) 
   			    --LEFT OUTER Join CodeLKUP CL WITH (NOLOCK) on (SKU.IVAS = CL.code)
                JOIN PickHeader PH WITH (NOLOCK) ON PH.OrderKey = O.OrderKey 
   		WHERE ( ISNULL(dbo.fnc_RTRIM(@cPickSlipNo), '') = '' OR PH.PickHeaderKey = @cPickSlipNo) 
   		and   ( ISNULL(dbo.fnc_RTRIM(@cLoadKey), '')    = '' OR O.loadkey = @cLoadKey )
         ORDER BY O.ExternOrderkey

      Select @n_cnt = @n_cnt + 1
   END

   
--Quit:
   SELECT * FROM @t_Result 
   ORDER BY RowID 
END

GO