SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/      
/* Stored Procedure: isp_RPT_WV_WAVPICKSUM_004                             */      
/* Creation Date: 04-NOV-2022                                              */      
/* Copyright: LFL                                                          */      
/* Written by: WZPang                                                      */      
/*                                                                         */      
/* Purpose: WMS-21095 - TW-NIK WM Report_WAVPICKSUM - CR                   */      
/*                                                                         */      
/* Called By: RPT_WV_WAVPICKSUM_004                                        */      
/*                                                                         */      
/* GitLab Version: 1.0                                                     */      
/*                                                                         */      
/* Version: 1.0                                                            */      
/*                                                                         */      
/* Data Modifications:                                                     */      
/*                                                                         */      
/* Updates:                                                                */      
/* Date         Author  Ver   Purposes                                     */    
/* 04-NOV-2022  WZPang  1.0   DevOps Combine Script                        */  
/***************************************************************************/  
CREATE   PROC [dbo].[isp_RPT_WV_WAVPICKSUM_004] ( 
      @c_Wavekey           NVARCHAR(10)  
    , @c_PreGenRptData     NVARCHAR(10) 
    )
AS  
BEGIN   
   SET NOCOUNT ON        
   SET ANSI_NULLS OFF        
   SET QUOTED_IDENTIFIER OFF        
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @c_pickheaderkey        NVARCHAR(10),        
           @n_continue             INT,        
           @c_errmsg               NVARCHAR(255),        
           @b_success              INT,        
           @n_err                  INT,        
           @n_pickslips_required   INT ,    
           @n_starttcnt            INT,    
           @c_FirstTime            NVARCHAR(1),    
           @c_PrintedFlag          NVARCHAR(1),    
           @c_PickSlipNo           NVARCHAR(20),    
           @c_storerkey            NVARCHAR(20),
	        @c_Status				     NVARCHAR(20),
	        @c_UserDefine02			  NVARCHAR(20)
	

	IF @c_PreGenRptData = '0' SET @c_PreGenRptData = ''
      
   SELECT @n_starttcnt=@@TRANCOUNT, @n_continue=1, @b_success=0, @n_err=0, @c_errmsg=''

   SELECT @c_Status = Wave.Status, @c_UserDefine02 = Wave.UserDefine02 FROM WAVE (NOLOCK)
   WHERE WaveKey = @c_Wavekey

   

   CREATE TABLE #TEMP_WAVPICKSUM004    
	(	OriWaveKey			NVARCHAR(20),
		PDQty				   INT,
		LocationCategory	NVARCHAR(20),
		PDLoc				   NVARCHAR(20) NULL,
		Storerkey			NVARCHAR(20) NULL,
		Pickheaderkey		NVARCHAR(20) NULL,
		Orderkey			   NVARCHAR(10) NULL
	)    
    
   IF @c_UserDefine02 <> 'GRS postdata done' 
	   BEGIN
		   SELECT @n_Continue = 3  
		   SELECT @n_err = 65410  
		   SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_err) + ': This Wave Not Get GRS Response Successfully. (isp_RPT_WV_WAVPICKSUM_004)'
		GOTO QUIT_SP
	END


	  -- Check if wavekey existed    
	IF EXISTS(SELECT 1 FROM PICKHEADER (NOLOCK)    
	    WHERE WaveKey = @c_Wavekey    
	    AND   Zone = '3')    
	BEGIN    
		SELECT @c_FirstTime = N'N'    
		SELECT @c_PrintedFlag = N'Y'    
	END    
	ELSE    
	BEGIN    
		SELECT @c_FirstTime = N'Y'    
		SELECT @c_PrintedFlag = N'N'    
	END    
	 
	 IF @c_PreGenRptData = 'Y' AND @c_Pregenrptdata = 'Y'   
	 BEGIN     
	      BEGIN TRAN    
	      -- Uses PickType as a Printed Flag    
	      UPDATE PICKHEADER WITH (ROWLOCK)    
	      SET PickType = '1',    
		   TrafficCop = NULL
	      WHERE WaveKey = @c_Wavekey    
	      AND Zone = '3'    
	      AND PickType = '0'    
	   
	      SELECT @n_err = @@ERROR    
	        IF @n_err <> 0    
	        BEGIN    
	           SELECT @n_continue = 3    
	           IF @@TRANCOUNT >= 1    
	           BEGIN    
	              ROLLBACK TRAN    
	              GOTO FAILURE    
	           END    
	        END    
	        ELSE    
	        BEGIN    
	           IF @@TRANCOUNT > 0    
	           BEGIN    
	              COMMIT TRAN    
	           END    
	           ELSE    
	           BEGIN    
	              SELECT @n_continue = 3    
	              ROLLBACK TRAN    
	              GOTO FAILURE    
	           END    
	        END      
	  END

	INSERT INTO #TEMP_WAVPICKSUM004 
	SELECT   C.UDF03 + WAVE.WaveKey AS OriWavekey
			,SUM(PICKDETAIL.Qty)  AS WaveKeyTotal 
			,LOC.LocationCategory
			,(SELECT COUNT(DISTINCT(PD.Loc))FROM dbo.PICKDETAIL PD(NOLOCK) JOIN WAVEDETAIL (NOLOCK) ON WAVEDETAIL.Orderkey = PD.Orderkey WHERE WAVEDETAIL.Wavekey = @c_Wavekey) AS LocationCount
			,PICKDETAIL.Storerkey
			,(SELECT PICKHEADER.PickHeaderKey FROM PICKHEADER (NOLOCK)    
         WHERE PICKHEADER.Wavekey = @c_wavekey    
         AND PICKHEADER.OrderKey = ORDERS.OrderKey    
         AND PICKHEADER.ZONE = '3')
			,ORDERS.Orderkey--,SUM(PICKDETAIL.Qty) AS PICKDETAILQty 
	FROM WAVE (NOLOCK)
   JOIN WAVEDETAIL  (NOLOCK) ON (WAVE.WaveKey = WAVEDETAIL.WaveKey)
   JOIN PICKDETAIL  (NOLOCK) ON (WAVEDETAIL.Orderkey = PICKDETAIL.Orderkey)
	JOIN ORDERS (NOLOCK) ON (WAVEDETAIL.Orderkey = ORDERS.Orderkey)
	JOIN LOC (NOLOCK) ON (PICKDETAIL.Loc = LOC.Loc)
	LEFT JOIN dbo.CODELKUP C (NOLOCK) ON C.listname  = 'WAVETYPE' AND c.code = Wave.WaveType AND c.Storerkey = ORDERS.storerkey
   WHERE WAVE.Wavekey = @c_Wavekey    
   GROUP BY WAVE.Wavekey, LOC.LocationCategory, PICKDETAIL.Storerkey, ORDERS.Orderkey, C.UDF03        
   ORDER BY LocationCategory

		 IF @c_PreGenRptData = 'Y'    
     BEGIN    
       SELECT @n_pickslips_required = COUNT(DISTINCT OrderKey)    
       FROM #TEMP_WAVPICKSUM004    
       WHERE ISNULL(RTRIM(Pickheaderkey),'') = ''     
    
       IF @@ERROR <> 0    
       BEGIN    
        GOTO FAILURE    
       END    
       ELSE IF @n_pickslips_required > 0    
       BEGIN    
        EXECUTE nspg_GetKey 'PICKSLIP', 9, @c_pickheaderkey OUTPUT, @b_success OUTPUT, @n_err  OUTPUT, @c_errmsg OUTPUT, 0, @n_pickslips_required    
    
        INSERT INTO PICKHEADER (PickHeaderKey, OrderKey, WaveKey, PickType, Zone, TrafficCop)    
        SELECT 'P' + RIGHT ( REPLICATE ('0', 9) +    
        dbo.fnc_LTrim( dbo.fnc_RTrim(    
        STR(CAST(@c_pickheaderkey AS INT) + (SELECT COUNT(DISTINCT OrderKey)    
                     FROM #TEMP_WAVPICKSUM004 AS Rank    
                     WHERE Rank.OrderKey < #TEMP_WAVPICKSUM004.OrderKey    
                     AND ISNULL(RTRIM(Rank.Pickheaderkey),'') = '' )     
          ) -- str    
          )) -- dbo.fnc_RTrim    
          , 9)    
         , OrderKey, 
		   @c_Wavekey, '0', '3', '' 
        FROM #TEMP_WAVPICKSUM004    
        WHERE ISNULL(RTRIM(Pickheaderkey),'') = ''   
        GROUP By OrderKey    
		
        UPDATE #TEMP_WAVPICKSUM004    
        SET Pickheaderkey = PICKHEADER.PickHeaderKey    
        FROM PICKHEADER (NOLOCK)
        WHERE PICKHEADER.WaveKey = @c_Wavekey    
        AND   PICKHEADER.OrderKey = #TEMP_WAVPICKSUM004.OrderKey    
        AND   PICKHEADER.Zone = '3'    
        AND   ISNULL(RTRIM(#TEMP_WAVPICKSUM004.Pickheaderkey),'') = ''   
       END    
    
		       GOTO SUCCESS    
		END  
		ELSE  
		BEGIN  
		  GOTO SUCCESS    
		END  
    
    
 FAILURE:    
 DELETE FROM #TEMP_WAVPICKSUM004    
 SUCCESS:    
  
 -- Do Auto Scan-in when Configkey is setup.    
 SET @c_StorerKey = ''    
 SET @c_PickSlipNo = ''    
    
   SELECT DISTINCT @c_StorerKey = StorerKey    
   FROM #TEMP_WAVPICKSUM004 (NOLOCK)    
  
    IF @c_PreGenRptData = 'Y'    
    BEGIN    
       IF EXISTS (SELECT 1 FROM STORERCONFIG (NOLOCK) WHERE CONFIGKEY = 'AUTOSCANIN'    
             AND SValue = '1' AND StorerKey = @c_StorerKey)    
       BEGIN    
        DECLARE C_AutoScanPickSlip CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
        SELECT DISTINCT Pickheaderkey    
          FROM #TEMP_WAVPICKSUM004 (NOLOCK)    
    
        OPEN C_AutoScanPickSlip    
        FETCH NEXT FROM C_AutoScanPickSlip INTO @c_PickSlipNo    
    
        WHILE @@FETCH_STATUS <> -1    
        BEGIN    
         IF NOT EXISTS (SELECT 1 FROM PICKINGINFO (NOLOCK) Where PickSlipNo = @c_PickSlipNo)    
         BEGIN    
          INSERT INTO PICKINGINFO (PickSlipNo, ScanInDate, PickerID, ScanOutDate)    
          VALUES (@c_PickSlipNo, GetDate(), sUser_sName(), NULL)    
    
          IF @@ERROR <> 0    
          BEGIN    
           SELECT @n_continue = 3    
           SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 61900    
           SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err) +    
                  ': Insert PickingInfo Failed. (ISP_RPT_WV_WAVPICKSUM_004)' + ' ( ' +    
                  ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '    
          END    
         END -- PickSlipNo Does Not Exist    
    
         FETCH NEXT FROM C_AutoScanPickSlip INTO @c_PickSlipNo    
        END    
        CLOSE C_AutoScanPickSlip    
        DEALLOCATE C_AutoScanPickSlip    
       END -- Configkey is setup    
  
    END  
     
	

    IF ISNULL(@c_PreGenRptData,'') = ''    
    BEGIN    
          SELECT @c_Wavekey AS WaveKey, SUM(PDQty) AS WaveKeyTotal , LocationCategory, PDLoc      
          FROM #TEMP_WAVPICKSUM004     
          group by LocationCategory, PDLoc  
          ORDER BY LocationCategory  
    END                    
	
	QUIT_SP:

	IF @n_Continue = 3 -- Error Occured - Process And Return    
   BEGIN  
      SET @b_Success = 0  
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt  
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
  
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_RPT_WV_WAVPICKSUM_004'  
      RAISERROR(@c_errmsg, 16, 1) WITH SETERROR -- SQL2012    
   END  
   ELSE  
   BEGIN  
      SET @b_Success = 1  
      WHILE @@TRANCOUNT > @n_StartTCnt  
      BEGIN  
         COMMIT TRAN  
      END  
   END
  
     IF OBJECT_ID('tempdb..#TEMP_WAVPICKSUM004') IS NOT NULL    
      DROP TABLE #TEMP_WAVPICKSUM004    
      
    
 END  
  
SET QUOTED_IDENTIFIER OFF


--END -- procedure   

GO