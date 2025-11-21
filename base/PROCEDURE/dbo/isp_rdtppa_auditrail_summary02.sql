SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_RdtPPA_AudiTrail_Summary02					      */
/* Creation Date: 04-May-2010                                           */
/* Copyright: IDS                                                       */
/* Written by: CHEWKP                                                   */
/*                                                                      */
/* Purpose: AuditTrail Report from RDTPPA (Summary By By CheckDate)     */
/*                                                                      */
/* Called By: report dw = r_dw_rdtppa_audittrail_summary02              */
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

CREATE PROC [dbo].[isp_RdtPPA_AudiTrail_Summary02]  (
  @c_Storerkey NVARCHAR(15),
  @d_FromDate DATETIME,
  @d_ToDate   DATETIME,
  @c_CheckerStart NVARCHAR(18),
  @c_CheckerEnd NVARCHAR(18)
) 
AS 
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   -- Declare temp tables
   Create TABLE #TempRDTPPA  (
      RowID            INT primary key,
      StorerKey        NVARCHAR( 15),
      RefKey           VARCHAR (18),
      Sku              VARCHAR (20) NULL,
	   Descr            VARCHAR (60) NULL,
	   UOMQty           INT NULL,
		PickQty_Pack	  INT NULL,
	   PQty             INT NULL,
	   CQty             INT NULL,
		CheckQty_EA		  INT NULL,
	   Status           VARCHAR (1) NULL,
	   UserName         VARCHAR (18) NULL,
	   AddDate          VARCHAR (10) NULL,
		MinTime			  DATETIME NULL,		
		MaxTime			  DATETIME NULL,
		NoofCheck        INT NULL
	   )

	
	Create TABLE #TempPAAUser  (
      StorerKey        NVARCHAR( 15),
      RefKey           VARCHAR (18),
		Username			  VARCHAR (18),
		AddDate          VARCHAR (10),
		MinTime			  VARCHAR (8) NULL,		
		MaxTime			  VARCHAR (8) NULL,
      PickQty_Pack	  INT NULL,
	   CheckQty_EA		  INT NULL,
		Variance			  INT NULL,
		SKUCount         INT NULL)
      
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
--      CONVERT(VARCHAR,PPA.AddDate,103) ,
--		(SELECT Min(convert(varchar,Adddate,108)) From RDT.RDTPPA (NOLOCK) Where Refkey = PPA.Refkey AND Storerkey = PPA.Storerkey),
--		(SELECT Max(convert(varchar,Adddate,108)) From RDT.RDTPPA (NOLOCK) Where Refkey = PPA.Refkey AND Storerkey = PPA.Storerkey),
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
		(SELECT Min(convert(varchar,Adddate,108)) From RDT.RDTPPA (NOLOCK) Where PickSlipNo = PPA.PickSlipNo AND Storerkey = PPA.Storerkey),
		(SELECT Max(convert(varchar,Adddate,108)) From RDT.RDTPPA (NOLOCK) Where PickSlipNo = PPA.PickSlipNo AND Storerkey = PPA.Storerkey),
      PPA.NoofCheck 
      FROM RDT.RDTPPA as PPA WITH (NOLOCK) 
      LEFT OUTER JOIN RDT.RDTUSER as rUSER WITH (NOLOCK) ON PPA.UserName = rUser.UserName 
      WHERE PPA.PickSlipNo <> ''
		AND PPA.Storerkey = ISNULL(@c_Storerkey,'')
		AND PPA.AddDate >= @d_FromDate AND PPA.AddDate <= @d_ToDate 
		AND PPA.Username Between @c_CheckerStart AND @c_CheckerEnd
      
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
		(SELECT Min(convert(varchar,Adddate,108)) From RDT.RDTPPA (NOLOCK) Where Loadkey = PPA.Loadkey AND Storerkey = PPA.Storerkey),
		(SELECT Max(convert(varchar,Adddate,108)) From RDT.RDTPPA (NOLOCK) Where Loadkey = PPA.Loadkey AND Storerkey = PPA.Storerkey),
      PPA.NoofCheck 
      FROM RDT.RDTPPA as PPA WITH (NOLOCK) 
      LEFT OUTER JOIN RDT.RDTUSER as rUSER WITH (NOLOCK) ON PPA.UserName = rUser.UserName 
      WHERE PPA.Loadkey <> ''
		AND PPA.Storerkey = ISNULL(@c_Storerkey,'')
		AND PPA.AddDate >= @d_FromDate AND PPA.AddDate <= @d_ToDate 
		AND PPA.Username Between @c_CheckerStart AND @c_CheckerEnd
      
      

		INSERT INTO #TempPAAUser
      SELECT Storerkey, RefKey, username, AddDate, convert(varchar,MinTime,108), convert(varchar,MaxTime,108),  SUM(PickQty_Pack) , SUM(CQty), SUM(PickQty_Pack) - SUM(CQty) , Count(SKU)
		FROM #TempRDTPPA
		Group By Storerkey, RefKey , username , AddDate ,convert(varchar,AddDate,108) , convert(varchar,MinTime,108), convert(varchar,MaxTime,108)


		SELECT Storerkey, RefKey, username, CONVERT(DATETIME,AddDate,103), MinTime, MaxTime,  CAST( DATEDIFF ( minute , MinTime , MaxTime ) AS INT) AS Mins,
				 CAST ((DATEDIFF ( minute , MinTime, MaxTime) / 60.00 ) AS Float(2) ) AS Hours, SUM(PickQty_Pack) , SUM(CheckQty_EA),
				 SUM(PickQty_Pack) - SUM(CheckQty_EA) , SKUCount, @d_FromDate , @d_Todate
		FROM #TempPAAUser
		Group By Storerkey, RefKey , username , CONVERT(DATETIME,AddDate,103) , MinTime, MaxTime, SKUCount
		Order By Storerkey, Refkey , username		

		DROP Table #TempPAAUser   
		DROP Table #TempRDTPPA 
		
END


GO