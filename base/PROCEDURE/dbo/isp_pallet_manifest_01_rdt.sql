SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/              
/* Store Procedure: isp_Pallet_Manifest_01_rdt                                */              
/* Creation Date: 18-Apr-2019                                                 */              
/* Copyright: IDS                                                             */              
/* Written by: WLCHOOI                                                        */              
/*                                                                            */              
/* Purpose: WMS-8675 - [KR] JUUL_KOREA_Pallet Manifest_Data_Window_NEW        */
/*                                                                            */              
/*                                                                            */              
/* Called By:  r_dw_pallet_manifest_01_rdt                                    */              
/*                                                                            */              
/* PVCS Version: 1.0                                                          */              
/*                                                                            */              
/* Version: 1.0                                                               */              
/*                                                                            */              
/* Data Modifications:                                                        */              
/*                                                                            */              
/* Updates:                                                                   */              
/* Date         Author    Ver.  Purposes                                      */
/*16/05/2019    WLCHOOI   1.0   Bug Fix (WL01)                                */    
/******************************************************************************/     
  
CREATE PROC [dbo].[isp_Pallet_Manifest_01_rdt]             
       (@c_Pickslipno     NVARCHAR(10) = '',
        @c_DropID         NVARCHAR(20) = '' )
          
AS            
BEGIN            
   SET NOCOUNT ON            
   SET ANSI_WARNINGS OFF            
   SET QUOTED_IDENTIFIER OFF            
   SET CONCAT_NULL_YIELDS_NULL OFF    
  
   DECLARE @n_Continue        INT = 1,
           @c_Storerkey       NVARCHAR(20) = '',
           @c_Address1        NVARCHAR(50) = '',    
           @c_Company         NVARCHAR(50) = '',
           @c_DeliveryDate    NVARCHAR(10) = '',
           @c_Externorderkey  NVARCHAR(50) = '',
           @c_GetDropID       NVARCHAR(20) = '',
           @c_Type            NVARCHAR(50) = '',
           @c_SKU             NVARCHAR(50) = '',
           @c_Descr           NVARCHAR(50) = '',
           @n_Casecnt         INT = 0,
           @c_C31             NVARCHAR(500) = '',
           @c_C32             NVARCHAR(500) = '',
           @c_C33             NVARCHAR(500) = '',
           @c_C34             NVARCHAR(500) = '',
           @c_C35             NVARCHAR(500) = '',
           @c_RPTLogo         NVARCHAR(500) = '',
           @c_Orderkey        NVARCHAR(10) = '',

           @n_Qty             INT = 0,
           @n_QtyPerCaseCnt   INT = 0,
           @c_Datawindow      NVARCHAR(100) = 'r_dw_pallet_manifest_01_rdt'

   IF @c_DropID = NULL SET @c_DropID = ''

   IF( @n_Continue = 1 OR @n_Continue = 2)
   BEGIN
      SELECT @c_Storerkey = ORD.Storerkey
      FROM PICKHEADER PIH (NOLOCK) 
      JOIN ORDERS ORD (NOLOCK) ON ORD.ORDERKEY = PIH.ORDERKEY
      WHERE PIH.pickheaderkey = @c_Pickslipno

      SET @c_C31 = (SELECT ISNULL(CL.Long,'') FROM CODELKUP CL WHERE CL.LISTNAME = 'RPTCONST' AND CL.STORERKEY = @c_Storerkey AND CL.CODE = 'C31')
      SET @c_C32 = (SELECT ISNULL(CL.Long,'') FROM CODELKUP CL WHERE CL.LISTNAME = 'RPTCONST' AND CL.STORERKEY = @c_Storerkey AND CL.CODE = 'C32')
      SET @c_C33 = (SELECT ISNULL(CL.Long,'') FROM CODELKUP CL WHERE CL.LISTNAME = 'RPTCONST' AND CL.STORERKEY = @c_Storerkey AND CL.CODE = 'C33')
      SET @c_C34 = (SELECT ISNULL(CL.Long,'') FROM CODELKUP CL WHERE CL.LISTNAME = 'RPTCONST' AND CL.STORERKEY = @c_Storerkey AND CL.CODE = 'C34')
      SET @c_C35 = (SELECT ISNULL(CL.Long,'') FROM CODELKUP CL WHERE CL.LISTNAME = 'RPTCONST' AND CL.STORERKEY = @c_Storerkey AND CL.CODE = 'C35') 

      SELECT @c_RPTLogo = ISNULL(CL1.NOTES,'')
      FROM CODELKUP CL1 (NOLOCK) 
      WHERE CL1.LISTNAME = 'RPTLOGO' AND CL1.STORERKEY = @c_Storerkey AND CL1.LONG = @c_Datawindow

      IF(@c_RPTLogo = NULL)
         SET @c_RPTLogo = ''
   END

   --Create temp table
   IF( @n_Continue = 1 OR @n_Continue = 2)
   BEGIN 
      CREATE TABLE #TEMP_PLTMAN01(
          Address1        NVARCHAR(50),
          Company         NVARCHAR(50),
          DeliveryDate    NVARCHAR(10),
          ExternOrderkey  NVARCHAR(50),
          DropID          NVARCHAR(50),
          Type            NVARCHAR(50),    
          SKU             NVARCHAR(50),    
          Descr           NVARCHAR(50),    
          Qty             INT, 
          QtyPerCaseCnt   INT,
          C31             NVARCHAR(500),
          C32             NVARCHAR(500),
          C33             NVARCHAR(500),
          C34             NVARCHAR(500),
          C35             NVARCHAR(500),
          RPTLogo         NVARCHAR(500)
      )
   END

   IF( @n_Continue = 1 OR @n_Continue = 2)
   BEGIN      
      DECLARE PSNO_CUR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
      SELECT DISTINCT 
             ISNULL(ST.Address1,'')   AS Address1            
           , ISNULL(OH.C_Company,'')  AS C_Company
           , CONVERT(CHAR(10), ISNULL(OH.DeliveryDate,'1900-01-01 00:00:00.000'), 111) AS DeliveryDate
           , ISNULL(OH.ExternOrderkey,'')   AS ExternOrderkey
           , ISNULL(PD.DropID,'')     AS DropID
           , ISNULL(OH.Type,'')       AS Type
           , ISNULL(PD.SKU,'')        AS SKU
           , ISNULL(S.DESCR,'')       AS Descr
           , ISNULL(P.CASECNT,0)      AS Casecnt
           , ISNULL(OH.Orderkey,'')   AS Orderkey
      FROM ORDERS OH (NOLOCK)
      JOIN STORER ST (NOLOCK) ON ST.STORERKEY = OH.STORERKEY
      JOIN PICKDETAIL PD (NOLOCK) ON PD.ORDERKEY = OH.ORDERKEY
      JOIN PICKHEADER PIH (NOLOCK) ON PIH.ORDERKEY = OH.ORDERKEY
      JOIN SKU S (NOLOCK) ON PD.SKU = S.SKU AND S.STORERKEY = OH.STORERKEY
      JOIN PACK P (NOLOCK) ON P.PACKKEY = S.PACKKEY
      WHERE PIH.pickheaderkey = @c_Pickslipno AND PD.DropID = @c_DropID

      OPEN PSNO_CUR      
      FETCH NEXT FROM PSNO_CUR INTO   @c_Address1     
                                     ,@c_Company      
                                     ,@c_DeliveryDate 
                                     ,@c_Externorderkey     
                                     ,@c_GetDropID       
                                     ,@c_Type         
                                     ,@c_SKU          
                                     ,@c_Descr   
                                     ,@n_Casecnt 
                                     ,@c_Orderkey 
                                  
      WHILE (@@FETCH_STATUS <> -1)  
      BEGIN 
      SET @n_Qty = 0
      SET @n_QtyPerCaseCnt = 0
    
      SELECT @n_Qty = SUM(Qty) FROM PICKDETAIL (NOLOCK) WHERE ORDERKEY = @c_Orderkey AND SKU = @c_SKU AND DropID = @c_GetDropID --WL01
    
      SELECT @n_QtyPerCaseCnt  = CASE WHEN @n_Casecnt > 0 THEN CAST(FLOOR(@n_Qty / @n_Casecnt) AS INT) ELSE 0 END  
    
      INSERT INTO #TEMP_PLTMAN01 (Address1, Company, DeliveryDate, ExternOrderkey, DropID, Type,          
                                  SKU, Descr, Qty, QtyPerCaseCnt, C31, C32, C33, C34, C35 ,RPTLogo )
    
      VALUES (@c_Address1, @c_Company, @c_DeliveryDate, @c_Externorderkey, @c_GetDropID, @c_Type,
             @c_SKU, @c_Descr, @n_Qty, @n_QtyPerCaseCnt, @c_C31, @c_C32, @c_C33, @c_C34, @c_C35, @c_RPTLogo )
    
    
      FETCH NEXT FROM PSNO_CUR INTO   @c_Address1     
                                     ,@c_Company      
                                     ,@c_DeliveryDate 
                                     ,@c_Externorderkey     
                                     ,@c_GetDropID       
                                     ,@c_Type         
                                     ,@c_SKU          
                                     ,@c_Descr   
                                     ,@n_Casecnt 
                                     ,@c_Orderkey
      END
   END

   SELECT * FROM #TEMP_PLTMAN01

   IF OBJECT_ID('tempdb..#TEMP_PLTMAN01') IS NOT NULL
      DROP TABLE #TEMP_PLTMAN01
               
END

GO