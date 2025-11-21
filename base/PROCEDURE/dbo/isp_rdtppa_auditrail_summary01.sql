SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_RdtPPA_AudiTrail_Summary01					      */
/* Creation Date: 04-May-2010                                           */
/* Copyright: IDS                                                       */
/* Written by: CHEWKP                                                   */
/*                                                                      */
/* Purpose: AuditTrail Report from RDTPPA (Summary By CheckDate)        */
/*                                                                      */
/* Called By: report dw = r_dw_rdtppa_audittrail_summary                */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/************************************************************************/

CREATE PROC [dbo].[isp_RdtPPA_AudiTrail_Summary01]  (
  @c_Storerkey NVARCHAR(15),
  @d_FromDate DATETIME,
  @d_ToDate   DATETIME
) 
AS 
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   -- Declare temp tables
   CREATE TABLE #TempRDTPPA  (
      RowID            INT ,
      StorerKey        NVARCHAR( 15),
      RefKey           VARCHAR (18),
      Sku              VARCHAR (20),
	   Descr            VARCHAR (60),
	   UOMQty           INT NULL,
		PickQty_Pack	  INT NULL,
	   PQty             INT NULL,
	   CQty             INT NULL,
		CheckQty_EA		  INT NULL,
	   Status           VARCHAR (1) NULL,
	   UserName         VARCHAR (18)NULL,
	   AddDate          VARCHAR (10)NULL,
	   NoofCheck        INT NULL
	   )
      
		SET @d_ToDate = CONVERT(DATETIME, CONVERT(VARCHAR(20), @d_ToDate, 112) + " 23:59:51.999" )
		

      -- Insert Data for Refkey    
--		INSERT INTO #TempRDTPPA 
--      SELECT RowRef, Storerkey, 
--      Refkey, Sku, Descr, 
--      UOMQty, 
--      (PQty / UOMQty ),
--      PQty ,
--      CQty , 
--      CQty * UOMQty ,  
--      Status, 
--      PPA.UserName,
--		CONVERT(VARCHAR,PPA.AddDate,103) ,
--      PPA.NoofCheck 
--      FROM RDT.RDTPPA as PPA WITH (NOLOCK) 
--      LEFT OUTER JOIN RDT.RDTUSER as rUSER WITH (NOLOCK) ON PPA.UserName = rUser.UserName 
--      WHERE PPA.Refkey <> '' 
--		AND PPA.Storerkey = ISNULL(@c_Storerkey,'')
--		AND PPA.AddDate >= @d_FromDate AND PPA.AddDate <= @d_ToDate 
      
      -- Insert Data for PSNo
		INSERT INTO #TempRDTPPA 
      SELECT RowRef, Storerkey, 
      PickSlipNo, Sku, Descr, 
      UOMQty, 
      (PQty / UOMQty ),
      PQty ,
      CQty , 
      CQty * UOMQty ,  
      Status, 
      PPA.UserName, 
      CONVERT(VARCHAR,PPA.AddDate,103) ,
      PPA.NoofCheck 
      FROM RDT.RDTPPA as PPA WITH (NOLOCK) 
      LEFT OUTER JOIN RDT.RDTUSER as rUSER WITH (NOLOCK) ON PPA.UserName = rUser.UserName 
      WHERE PPA.PickSlipNo <> ''
		AND PPA.Storerkey = ISNULL(@c_Storerkey,'')
		AND PPA.AddDate >= @d_FromDate AND PPA.AddDate <= @d_ToDate 
      
      -- Insert Data for Loadkey    
		INSERT INTO #TempRDTPPA 
      SELECT RowRef, Storerkey, 
      Loadkey, Sku, Descr, 
      UOMQty, 
      (PQty / UOMQty ),
      PQty ,
      CQty , 
      CQty * UOMQty ,  
      Status, 
      PPA.UserName, 
      CONVERT(VARCHAR,PPA.AddDate,103) ,
      PPA.NoofCheck 
      FROM RDT.RDTPPA as PPA WITH (NOLOCK) 
      LEFT OUTER JOIN RDT.RDTUSER as rUSER WITH (NOLOCK) ON PPA.UserName = rUser.UserName 
      WHERE PPA.Loadkey <> ''
		AND PPA.Storerkey = ISNULL(@c_Storerkey,'')
		AND PPA.AddDate >= @d_FromDate AND PPA.AddDate <= @d_ToDate 
      
      
      SELECT Storerkey, RefKey, CONVERT(DATETIME,AddDate,103), SUM(PickQty_Pack) , SUM(CQty),  SUM(PickQty_Pack) - SUM(CQty) , Count(SKU)
      , @d_FromDate , @d_Todate
		FROM #TempRDTPPA 
		Group By Storerkey, RefKey , CONVERT(DATETIME,AddDate,103)
		
		DROP Table #TempRDTPPA     


END


GO