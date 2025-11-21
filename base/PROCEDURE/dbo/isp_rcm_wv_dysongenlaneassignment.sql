SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Stored Procedure: isp_RCM_WV_DysonGenLaneAssignment                  */    
/* Creation Date: 07-Nov-2019                                           */    
/* Copyright: LF                                                        */    
/* Written by:                                                          */    
/*                                                                      */    
/* Purpose:  WMS-11045 - Dyson_Lane Assignment                          */  
/*                                                                      */    
/*                                                                      */     
/* Called By: WaveKey RCM configure at listname 'RCMConfig'             */     
/*                                                                      */    
/* Parameters:                                                          */    
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
    
CREATE PROCEDURE [dbo].[isp_RCM_WV_DysonGenLaneAssignment]    
   @c_Wavekey NVARCHAR(10),       
   @b_success  int OUTPUT,    
   @n_err      int OUTPUT,    
   @c_errmsg   NVARCHAR(225) OUTPUT,    
   @c_code     NVARCHAR(30)=''    
AS    
BEGIN     
   SET NOCOUNT ON    
   SET ANSI_DEFAULTS OFF      
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
    
   DECLARE @n_continue int,    
           @n_cnt int,    
           @n_starttcnt int    
               
   DECLARE @c_Facility  NVARCHAR(5),    
           @c_storerkey NVARCHAR(15),  
           @c_LoadKey   NVARCHAR(15),
           @c_Loc       NVARCHAR(10) = ''
                  
   SELECT @n_Continue = 1, @b_success = 1, @n_starttcnt=@@TRANCOUNT, @c_errmsg='', @n_err=0     

   BEGIN TRAN

   CREATE TABLE #TEMP_WAVE(
      Loadkey      NVARCHAR(10), 
      Orderkey     NVARCHAR(10),
      Shipperkey   NVARCHAR(10)
   )

   INSERT INTO #TEMP_WAVE
   SELECT LPD.Loadkey
        , LPD.Orderkey
        , ISNULL(OH.ShipperKey,'')
   FROM WAVEDETAIL WD (NOLOCK)
   JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = WD.OrderKey
   JOIN LOADPLANDETAIL LPD (NOLOCK) ON LPD.OrderKey = OH.OrderKey
   WHERE WD.WaveKey = @c_Wavekey AND OH.[Status] IN ('0','2','3','5')
   
   SELECT TOP 1 @c_Facility = Facility,    
                @c_Storerkey = Storerkey    
   FROM ORDERS (NOLOCK)    
   JOIN WAVEDETAIL WD (NOLOCK) ON WD.ORDERKEY = ORDERS.ORDERKEY  
   WHERE WD.WaveKey = @c_Wavekey  

   IF NOT EXISTS (SELECT 1 FROM CODELKUP CL (NOLOCK)
                  JOIN #TEMP_WAVE t ON t.Shipperkey = CL.Code AND CL.LISTNAME = 'DYSONLANE' AND CL.Storerkey = @c_Storerkey)
   BEGIN
      SELECT @n_continue = 3
      SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=63800   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+":One or multiple Shipperkey not maintained in Codelkup = DYSONLANE'. (isp_RCM_WV_DysonGenLaneAssignment)" + 
                       " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      GOTO ENDPROC
   END
 
   DECLARE CUR_LoadKey CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
   SELECT DISTINCT t.Loadkey
   FROM #TEMP_WAVE t  

   OPEN CUR_LoadKey    
   
   FETCH NEXT FROM CUR_LoadKey INTO @c_loadkey                             
   
   WHILE @@FETCH_STATUS <> -1    
   BEGIN   
      SELECT TOP 1 @c_Loc = ISNULL(CL.Long,'')
      FROM CODELKUP CL (NOLOCK)
      JOIN #TEMP_WAVE t ON t.Shipperkey = CL.Code AND CL.LISTNAME = 'DYSONLANE' AND CL.Storerkey = @c_Storerkey
      WHERE t.Loadkey = @c_loadkey

      IF ISNULL(@c_Loc,'') = ''
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=63810   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+":Dock is empty or NULL value. (isp_RCM_WV_DysonGenLaneAssignment)" + 
                          " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
         GOTO ENDLOOP
      END

      IF NOT EXISTS (SELECT 1 FROM LOC (NOLOCK) WHERE LOC = @c_Loc)
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=63820   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+":Dock not setup in LOC table. (isp_RCM_WV_DysonGenLaneAssignment)" + 
                          " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
         GOTO ENDLOOP
      END

      IF EXISTS (SELECT 1 FROM LoadPlanLaneDetail (NOLOCK) WHERE Loadkey = @c_loadkey)
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=63830   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+":Loadkey: " + LTRIM(RTRIM(@c_loadkey)) + " - LoadPlanLaneDetail table already have records! (isp_RCM_WV_DysonGenLaneAssignment)" + 
                          " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
         GOTO ENDLOOP
      END

      INSERT INTO LoadPlanLaneDetail(Loadkey, ExternOrderKey, ConsigneeKey, LP_LaneNumber, LocationCategory, LOC, [Status], Notes, MBOLKey)
      SELECT TOP 1 LPD.Loadkey, OH.Externorderkey, OH.Consigneekey, '00001', L.LocationCategory, L.Loc, '0', '',''
      FROM LOADPLANDETAIL LPD (NOLOCK)
      JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = LPD.OrderKey
      JOIN LOC L (NOLOCK) ON L.LOC = @c_Loc
      WHERE LPD.Loadkey = @c_Loadkey

      SELECT @n_err = @@ERROR

      IF (@n_err <> 0)
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=63810   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+":Insert LoadPlanLaneDetail Failed! (isp_RCM_WV_DysonGenLaneAssignment)" + 
                          " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
         GOTO ENDLOOP
      END

      FETCH NEXT FROM CUR_LoadKey INTO @c_Loadkey    
   END    
ENDLOOP:
   CLOSE CUR_LoadKey    
   DEALLOCATE CUR_LoadKey 

ENDPROC:     
    
   IF @n_continue=3  -- Error Occured - Process And Return    
  BEGIN    
     SELECT @b_success = 0    
     IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_starttcnt    
     BEGIN    
        ROLLBACK TRAN    
     END    
  ELSE    
     BEGIN    
        WHILE @@TRANCOUNT > @n_starttcnt    
        BEGIN    
           COMMIT TRAN    
        END    
     END    
     execute nsp_logerror @n_err, @c_errmsg, 'isp_RCM_WV_DysonGenLaneAssignment'    
     RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012    
     RETURN    
  END    
  ELSE    
     BEGIN    
        SELECT @b_success = 1    
        WHILE @@TRANCOUNT > @n_starttcnt    
        BEGIN    
           COMMIT TRAN    
        END    
        RETURN    
     END        
END -- End PROC    


GO