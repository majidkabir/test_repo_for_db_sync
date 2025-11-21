SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/
/* Stored Proc : isp_GetPickSummary                                        */
/* Creation Date: 02-08-2016                                               */
/* Copyright: IDS                                                          */
/* Written by: CSCHONG                                                     */
/*                                                                         */
/* Purpose: SOS# - 374474 [Unilever] Picking List Summary Report           */
/*                                                                         */
/*                                                                         */
/* Usage:                                                                  */
/*                                                                         */
/* Local Variables:                                                        */
/*                                                                         */
/* Called By: r_dw_pick_summary                                            */
/*                                                                         */
/*                                                                         */
/* PVCS Version: 1.0                                                       */
/*                                                                         */
/* Version: 1.0                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date        Author      Ver   Purposes                                  */
/***************************************************************************/

CREATE PROC [dbo].[isp_GetPickSummary] (@c_loadkey NVARCHAR(10))
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   -- Added by YokeBeen on 30-Jul-2004 (SOS#25474) - (YokeBeen01)
   -- Added SKU.SUSR3 (Agency) & ORDERS.InvoiceNo.      
   
   
   
DECLARE     @c_company NVARCHAR(45),
            @c_address1 NVARCHAR(45),
            @c_address2 NVARCHAR(45),
            @c_address3 NVARCHAR(45),
            @c_address4 NVARCHAR(45)
            
                 
DECLARE @n_starttcnt INT
SELECT  @n_starttcnt = @@TRANCOUNT


SET @c_company = ''
SET @c_address1 =''
SET @c_address2 = ''
SET @c_address3= ''
SET @c_address4 = ''


   CREATE TABLE #temp_picksumm
         (LoadKey        NVARCHAR(10),
          C_Company        NVARCHAR(45),
          C_Addr1          NVARCHAR(45) NULL,
          C_Addr2          NVARCHAR(45) NULL,
          C_Addr3          NVARCHAR(45) NULL,
          C_Addr4          NVARCHAR(45) NULL,
          loc_pickzone     NVARCHAR(10) NULL,
          rklpso          NVARCHAR(10) NULL,
          plt              INT,
          ctn              INT,
          ea               INT,
          locCount         INT
      )
    
		SELECT TOP 1 @c_company = c_company, @c_address1 = c_address1, 
		             @c_address2 = c_address2,@c_address3 = c_address3,@c_address4 = c_address4
		FROM orders(nolock)
		WHERE  loadkey = @c_LoadKey
		ORDER BY orderkey

   INSERT INTO #temp_picksumm
      (LoadKey,  c_Company,      C_Addr1,       C_Addr2, 
       C_Addr3,  C_Addr4,      loc_pickzone,    rklpso,          plt,
      ctn,      ea,locCount 
      )
   SELECT LP.LoadKey,    
         ISNULL(@c_company,''),
         ISNULL(@c_address1,''),
         ISNULL(@c_address2,''),
         ISNULL(@c_address3,''),
         ISNULL(@c_address4,''),
         LOC.Pickzone,
         rkl.Pickslipno as rklpso,
        SUM(FLOOR(CAST(PDET.qty as FLOAT)/p.pallet)) as 'PLT',
       SUM(FLOOR((PDET.qty%CAST(p.pallet as INT))/p.casecnt)) as 'CTN',
      SUM((PDET.qty%CAST(p.pallet as INT))%CAST(p.casecnt as int)) as 'EA',
      COUNT(DISTINCT loc.loc)
  FROM LoadPlan  LP WITH (NOLOCK)   
  JOIN LoadPlanDetail LPDET WITH (NOLOCK) ON  ( LP.LoadKey = LPDet.LoadKey ) 
  JOIN  ORDERS ORD WITH (NOLOCK)  ON ( LP.Loadkey = ORD.Loadkey ) and
                                     ( LPDET.Orderkey = ORD.Orderkey ) 
  JOIN ORDERDETAIL ORDDET WITH (NOLOCK) ON  ( ORD.Orderkey = ORDDET.Orderkey )
  JOIN  SKU S WITH (NOLOCK) ON  ( ORDDET.Storerkey = S.Storerkey ) and
                                ( ORDDET.Sku = S.Sku )  
  JOIN PICKDETAIL PDET WITH (NOLOCK) ON   ( PDET.Orderkey = ORDDET.Orderkey ) and
                                          ( PDET.Orderlinenumber = ORDDET.Orderlinenumber ) 
  LEFT OUTER JOIN RefKeyLookup rkl (NOLOCK) ON (rkl.PickDetailKey = PDET.PickDetailKey)
  JOIN LOC WITH (NOLOCK)   ON ( PDET.Loc = Loc.Loc )         
   LEFT JOIN PACK P ON P.PackKey = PDET.PACKKey
   WHERE  ORD.status IN ('1','2','3','4') 
       AND  ( LP.Loadkey = @c_LoadKey ) 
Group By LP.LoadKey,    
         --ORD.C_company,
         --ORD.C_Address1,
         --ORD.C_Address2,
         --ORD.C_Address3,
         --ORD.C_Address4,
         LOC.Pickzone,
         rkl.Pickslipno


   SELECT * FROM #temp_picksumm
   ORDER BY rklpso
  
   DROP Table #temp_picksumm

   WHILE @@TRANCOUNT < @n_starttcnt
   BEGIN
      BEGIN TRAN
   END
END

GO