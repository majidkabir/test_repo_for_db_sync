SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Stored Procedure: isp_importer_label_02                              */    
/* Creation Date: 29-Jul-2021                                           */    
/* Copyright: LFL                                                       */    
/* Written by:                                                          */    
/*                                                                      */    
/* Purpose: WMS-17565 - SG THGBT Importer Label                         */    
/*                                                                      */    
/* Called By: PB dw: r_dw_importer_label_02                             */    
/*                                                                      */    
/* PVCS Version: 1.0                                                    */    
/*                                                                      */    
/* Version: 7.0                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author  Ver.  Purposes                                  */    
/* 26-OCT-2021  NJOW    1.0   DEVOPS combine script                     */
/************************************************************************/    
    
CREATE PROC [dbo].[isp_importer_label_02] (    
       @c_PickslipNo NVARCHAR(10),    
       @c_Sku NVARCHAR(20),
       @c_Qty INT = '0',   
       @c_Lottable01 NVARCHAR(18) = ''  
 )    
 AS    
 BEGIN    
   SET NOCOUNT ON   -- SQL 2005 Standard  
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF     
   SET CONCAT_NULL_YIELDS_NULL OFF      
   
   DECLARE @c_Country   NVARCHAR(30),
           @c_Storerkey NVARCHAR(15),
           @c_Notes     NVARCHAR(1000),
           @n_Qty       INT,
           @dt_MfgDate  DATETIME,
           @c_Wavekey   NVARCHAR(10),
           @c_Loadkey   NVARCHAR(10),
           @c_Orderkey  NVARCHAR(10)

   IF ISNUMERIC(@c_qty) = 1
      SET @n_Qty = CAST(@c_Qty AS INT)
   ELSE
      SET @n_Qty = 1
             
   CREATE TABLE #TMP_LABELS (MfgDate DATETIME NULL,ColTitle NVARCHAR(10) NULL, Address NVARCHAR(1000) NULL)
      
   SELECT @c_Country = O.C_Country,
          @c_Storerkey = O.Storerkey,
          @c_Orderkey = O.Orderkey,
          @c_Loadkey = O.Loadkey,         
          @c_Wavekey = O.Userdefine09
	 FROM PICKHEADER PKH (NOLOCK)
	 JOIN ORDERS O (NOLOCK) ON PKH.Orderkey = O.Orderkey
	 WHERE PKH.Pickheaderkey = @c_Pickslipno
	 
	 IF @@ROWCOUNT = 0
	 BEGIN
	    SELECT TOP 1 @c_Country = O.C_Country,
	                 @c_Storerkey = O.Storerkey,
                   @c_Orderkey = O.Orderkey,
                   @c_Loadkey = O.Loadkey,         
                   @c_Wavekey = O.Userdefine09	                 
	    FROM PICKHEADER PKH (NOLOCK)
	    JOIN LOADPLANDETAIL LPD (NOLOCK) ON PKH.ExternOrderkey = LPD.Loadkey 
	    JOIN ORDERS O (NOLOCK) ON LPD.Orderkey = O.Orderkey
	    WHERE PKH.Pickheaderkey = @c_Pickslipno	 	 
	 END	 	 	 
	 
	 SELECT @c_Notes = CL.Notes
   FROM SKU (NOLOCK) 
   JOIN CODELKUP CL (NOLOCK) ON SKU.Busr4 = CL.Code AND SKU.Storerkey = CL.Storerkey
   WHERE CL.Listname = 'IMPLBL'
   AND SKU.Storerkey = @c_Storerkey
   AND SKU.Sku = @c_Sku
	 
	 IF @@ROWCOUNT > 0 AND ISNULL(@c_Country,'') IN ('SG')
   BEGIN
   	  SELECT TOP 1 @dt_MfgDate = LA.Lottable15
   	  FROM PICKDETAIL PD (NOLOCK)
   	  JOIN LOTATTRIBUTE LA (NOLOCK) ON PD.Lot = LA.Lot
   	  WHERE PD.Orderkey = @c_Orderkey
   	  AND PD.Storerkey = @c_Storerkey
   	  AND PD.Sku = @c_Sku
   	  AND LA.Lottable01 = @c_Lottable01
   	  
   	  IF @@ROWCOUNT = 0
   	  BEGIN
   	     SELECT TOP 1 @dt_MfgDate = LA.Lottable15
   	     FROM PICKDETAIL PD (NOLOCK)
   	     JOIN LOADPLANDETAIL LPD (NOLOCK) ON PD.Orderkey = LPD.Orderkey
   	     JOIN LOTATTRIBUTE LA (NOLOCK) ON PD.Lot = LA.Lot
   	     WHERE LPD.Loadkey = @c_Loadkey
   	     AND PD.Storerkey = @c_Storerkey
   	     AND PD.Sku = @c_Sku
   	     AND LA.Lottable01 = @c_Lottable01
   	     
   	     IF @@ROWCOUNT = 0
   	     BEGIN
            SELECT TOP 1 @dt_MfgDate = LA.Lottable15
   	        FROM PICKDETAIL PD (NOLOCK)
   	        JOIN WAVEDETAIL WD (NOLOCK) ON PD.Orderkey = WD.Orderkey
   	        JOIN LOTATTRIBUTE LA (NOLOCK) ON PD.Lot = LA.Lot
   	        WHERE WD.Wavekey = @c_Wavekey
   	        AND PD.Storerkey = @c_Storerkey
   	        AND PD.Sku = @c_Sku
   	        AND LA.Lottable01 = @c_Lottable01
   	     END
   	  END 
   	    	  
      WHILE @n_Qty > 0 
      BEGIN
         INSERT INTO #TMP_LABELS (MfgDate, ColTitle, Address) VALUES (@dt_MfgDate, 'MFG Date:', @c_Notes)        --(CS01)       
  	     SELECT @n_Qty = @n_Qty - 1                                                            
      END                                                                
   END                                                                                                  
	       
   SELECT MfgDate ,ColTitle, Address
   FROM #TMP_LABELS    
END    

GO