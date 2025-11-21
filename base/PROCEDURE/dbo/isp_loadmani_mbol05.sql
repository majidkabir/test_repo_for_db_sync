SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Store Procedure:  isp_loadmani_mbol05                                */    
/* Creation Date:  03-Sep-2019                                          */    
/* Copyright: LFL                                                       */    
/* Written by: WLChooi                                                  */    
/*                                                                      */    
/* Purpose: Change to call SP for Customize                             */    
/*        : WMS-10054 - [MY]-LEVIS MBOL PRINT DISPATCH SUMMARY-CR       */    
/*                                                                      */    
/* Input Parameters: @c_mbolkey  - mbolkey                              */    
/*                                                                      */    
/* Output Parameters:  None                                             */    
/*                                                                      */    
/* Return Status:  None                                                 */    
/*                                                                      */    
/* Usage:  Used for report dw = r_dw_load_manifest_mbol05               */  
/*      :  Copy from r_dw_load_manifest_mbol                            */   
/*                                                                      */    
/* Local Variables:                                                     */    
/*                                                                      */    
/* Called By:                                                           */    
/*                                                                      */    
/* PVCS Version: 1.0                                                    */    
/*                                                                      */    
/* Version: 5.4                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author        Purposes                                  */  
/* 10/09/2019   mingle        Add mapping(WMS-10818)ml01                */  
/* 26/12/2019   WLChooi       WMS-11566 - Sort by Externorderkey (WL01) */
/************************************************************************/    
CREATE PROC [dbo].[isp_loadmani_mbol05] (    
     @c_mbolkey   NVARCHAR(10),
     @c_Orderkey  NVARCHAR(10) = '',
     @c_Type      NVARCHAR(5) = ''  
)    
 AS    
BEGIN    
    SET NOCOUNT ON     
    SET QUOTED_IDENTIFIER OFF     
    SET CONCAT_NULL_YIELDS_NULL OFF    
    
    DECLARE @n_continue       INT     
         ,  @c_errmsg         NVARCHAR(255)     
         ,  @b_success        INT     
         ,  @n_err            INT     
         ,  @n_StartTCnt      INT    
    
   SET @n_StartTCnt = @@TRANCOUNT    
    
   WHILE @@TRANCOUNT > 0     
   BEGIN    
      COMMIT TRAN    
   END
   
   --ml01 start
   CREATE TABLE #TEMPMBOL05(
      Orderkey        NVARCHAR(10) NULL, 
      Storerkey       NVARCHAR(15) NULL,                  
      Consigneekey    NVARCHAR(15) NULL,                   
      C_Company       NVARCHAR(45) NULL,                      
      C_Address1      NVARCHAR(45) NULL,                     
      C_Address2      NVARCHAR(45) NULL,                     
      C_Address3      NVARCHAR(45) NULL,                     
      C_Address4      NVARCHAR(45) NULL,                     
      C_City          NVARCHAR(15) NULL,                        
      C_Zip           NVARCHAR(15) NULL,                          
      MbolKey         NVARCHAR(15) NULL,                        
      DriverName      NVARCHAR(15) NULL,                     
      AddDate         DATETIME NULL,                          
      ExternOrderkey  NVARCHAR(50) NULL,                 
      InvoiceNo       NVARCHAR(15) NULL,                      
      Remarks         NVARCHAR(15) NULL,                        
      CartonNo        NVARCHAR(15) NULL,                        
      Deliverydate    DATETIME NULL,                        
      BUYERPO         NVARCHAR(30) NULL,  
      Facility        NVARCHAR(15) NULL,
      ShowBarcode     NVARCHAR(1) NULL,
      ShowFacility    NVARCHAR(1) NULL,
      [Route]         NVARCHAR(100) NULL,
      STCompany       NVARCHAR(100) NULL,     
      STAddress1      NVARCHAR(100) NULL,   
      STAddress2      NVARCHAR(100) NULL,   
      STAddress3      NVARCHAR(100) NULL,   
      STAddress4      NVARCHAR(100) NULL,      
      Departuredate   DATETIME NULL,                                          
      C_phone1        NVARCHAR(100) NULL              
   )                                                
                                                
   INSERT INTO #TEMPMBOL05                          
   SELECT ORDERDETAIL.OrderKey,                     
          ORDERDETAIL.StorerKey,                       
          ORDERS.ConsigneeKey,                         
          ORDERS.C_Company,                            
          ORDERS.C_Address1,                           
          ORDERS.C_Address2,                           
          ORDERS.C_Address3,                           
          ORDERS.C_Address4,                   
          ORDERS.C_City,
          ORDERS.C_Zip,
          MBOL.MbolKey,
          MBOL.DriverName,
          MBOL.AddDate,
          ORDERS.ExternOrderKey,
          ORDERS.InvoiceNo,
          Remarks=CONVERT(NVARCHAR(40), MBOL.Remarks),
          CartonNo=MAX(ISNULL(PACKDETAIL.CartonNo,0)), 
          ORDERS.Deliverydate, 
          ORDERS.BUYERPO,
          MBOL.Facility,
          ISNULL(CL.Short,'N') as 'ShowBarCode',
          ISNULL(CL1.Short,'N') as 'ShowFacility',
          --ml01 start
          ORDERS.ROUTE,
          Storer.Company,
          Storer.Address1,
          Storer.Address2,
          Storer.Address3,
          Storer.Address4,
          --ORDERS.MBOLKEY,
          MBOL.departuredate,
          --ORDERS.Storerkey,
          --ORDERS.Facility,
          Orders.C_phone1
          --Orders.Orderkey,
          --Packdetail.cartonno
          --Mbol.Remarks
          --ml01 end           
   FROM ORDERDETAIL (NOLOCK)   
   INNER JOIN ORDERS (NOLOCK) ON ( ORDERDETAIL.OrderKey = ORDERS.OrderKey )   
   INNER JOIN MBOL (NOLOCK) ON ( ORDERDETAIL.MBOLKey = MBOL.MbolKey )
   INNER JOIN MBOLDETAIL (NOLOCK) ON ( ORDERDETAIL.OrderKey = MBOLDETAIL.OrderKey ) 
   --ml01 start
   INNER JOIN STORER (NOLOCK) ON ( orders.consigneekey  = storer.storerkey   )
   --ml01 end
   LEFT OUTER JOIN PACKHEADER (NOLOCK) ON ( ORDERS.OrderKey = PACKHEADER.OrderKey )
   LEFT OUTER JOIN PACKDETAIL (NOLOCK) ON ( PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo )
   LEFT JOIN CODELKUP CL WITH (NOLOCK) ON (CL.ListName = 'REPORTCFG' AND CL.Long = 'r_dw_load_manifest_mbol05'
                     AND CL.Code = 'SHOWBARCODE' AND CL.Storerkey = ORDERS.StorerKey)
   LEFT JOIN CODELKUP CL1 WITH (NOLOCK) ON (CL1.ListName = 'REPORTCFG' AND CL1.Long = 'r_dw_load_manifest_mbol05'
                     AND CL1.Code = 'SHOWFACILITY' AND CL1.Storerkey = ORDERS.StorerKey)
   WHERE ( MBOL.MbolKey = @c_mbolkey )
   GROUP BY	ORDERDETAIL.OrderKey,   
            ORDERDETAIL.StorerKey,
            ORDERS.ConsigneeKey,   
            ORDERS.C_Company,   
            ORDERS.C_Address1,   
            ORDERS.C_Address2,  
            ORDERS.C_Address3,
            ORDERS.C_Address4,
            ORDERS.C_City,
            ORDERS.C_Zip,     
            MBOL.MbolKey,
            MBOL.DriverName, 
            MBOL.AddDate,   
            ORDERS.ExternOrderKey, 
            ORDERS.InvoiceNo,
            CONVERT(NVARCHAR(40), MBOL.Remarks),
            ORDERS.Deliverydate,
            ORDERS.BUYERPO,
            MBOL.Facility,
            ISNULL(CL.Short,'N'),
            ISNULL(CL1.Short,'N') ,
            --ml01 start
            ORDERS.ROUTE,
            Storer.Company,
            Storer.Address1,
            Storer.Address2,
            Storer.Address3,
            Storer.Address4,
            --ORDERS.MBOLKEY,
            Orders.InvoiceNo,
            MBOL.departuredate,
            --ORDERS.Storerkey,
            --ORDERS.Facility,
            Orders.C_phone1
            --Orders.Orderkey,
            --Packdetail.cartonno
            --Mbol.Remarks

   IF @c_Type = 'H'
   BEGIN
      SELECT TOP 1 Mbolkey, Orderkey, ShowBarcode, Storerkey FROM #TEMPMBOL05
   END  
   ELSE IF @c_Type = 'H2'
   BEGIN
      SELECT TOP 1 Consigneekey, Departuredate, Route, Mbolkey, Storerkey, Facility, STCompany, 
                   STAddress1, STAddress2, STAddress3, STAddress4, 
                   C_Phone1, ShowFacility
      FROM #TEMPMBOL05
   END
   ELSE
      SELECT Orderkey, ExternOrderkey, InvoiceNo, BUYERPO, CartonNo, Remarks FROM #TEMPMBOL05 --ml01 end
      ORDER BY ExternOrderkey  --WL01

   QUIT_SP:    
   WHILE @@TRANCOUNT < @n_StartTCnt    
   BEGIN    
      BEGIN TRAN     
   END    
    
   /* #INCLUDE <SPTPA01_2.SQL> */      
   IF @n_continue=3  -- Error Occured - Process And Return      
   BEGIN      
      SELECT @b_success = 0      
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT >= @n_StartTCnt      
      BEGIN      
         ROLLBACK TRAN      
      END      
      ELSE      
      BEGIN      
         WHILE @@TRANCOUNT > @n_StartTCnt      
         BEGIN      
            COMMIT TRAN      
         END      
      END      
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_loadmani_mbol05'      
      --RAISERROR @n_err @c_errmsg     
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012      
      RETURN      
   END      
   ELSE      
   BEGIN      
      SELECT @b_success = 1      
      WHILE @@TRANCOUNT > @n_StartTCnt      
      BEGIN      
         COMMIT TRAN      
      END      
   END    
    
END 

GO