SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_GetLoadPlanInfo                                */
/* Creation Date: 27-Jan-2011                                           */
/* Copyright: IDS                                                       */
/* Written by: NJOW                                                     */
/*                                                                      */
/* Purpose: SOS#200194                                                  */
/*                                                                      */
/* Called By: Load Plan information -> show extended info               */ 
/*                                                                      */
/* Parameters:                                                          */
/*                                                                      */
/* PVCS Version: 1.0	                                                   */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver. Purposes                                 */
/* 28-Jan-2019  TLTING_ext 1.1  enlarge externorderkey field length     */
/************************************************************************/
CREATE  PROCEDURE [dbo].[isp_GetLoadPlanInfo]
        @c_loadkey NVARCHAR(10)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF  
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE 	@n_continue int,
            @n_cnt int,
            @c_Externorderkey NVARCHAR(50),  --tlting_ext
            @n_TotalCarton int,
            @n_TotalPallet int,
            @n_TotalLoose int,
            @n_NoOfLoosePPKOrder int
   
   SELECT @n_continue = 1    
   
	IF @n_continue = 1 OR @n_continue = 2
	BEGIN
       DECLARE CUR_LPOrder CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
           SELECT DISTINCT LOADPLANDETAIL.Externorderkey
           FROM LOADPLANDETAIL (NOLOCK)
           WHERE LOADPLANDETAIL.Loadkey = @c_loadkey

       OPEN CUR_LPOrder  
          
       FETCH NEXT FROM CUR_LPOrder INTO @c_Externorderkey   
    
       SET @n_NoOfLoosePPKOrder = 0
       
       WHILE @@FETCH_STATUS<>-1  
       BEGIN  

	       EXEC isp_GetPPKPltCase2
	          @c_LoadKey=@c_Loadkey,  
             @c_ExternOrderkey=@c_Externorderkey,  
             @n_TotalCarton=@n_TotalCarton OUTPUT,  
             @n_TotalPallet=@n_TotalPallet OUTPUT,  
             @n_TotalLoose=@n_TotalLoose OUTPUT
             
          IF @n_TotalLoose > 0 
             SET @n_NoOfLoosePPKOrder = @n_NoOfLoosePPKOrder + 1
   
          FETCH NEXT FROM CUR_LPOrder INTO @c_Externorderkey   
             
       END
	END -- continue     
	
	SELECT @n_NoOfLoosePPKOrder

END

GO